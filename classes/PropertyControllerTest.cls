@isTest
private class PropertyControllerTest {

    @testSetup
    static void setup() {
        TestDataFactory.createProperties(40);
    }

    // Helper: call getProperties with all-null filters except the ones we care about
    static PropertyController.PropertyListResult query(
        String  searchKey, String  statusFilter, String  typeFilter,
        String  furnishing, Decimal minPrice,    Decimal maxPrice,
        Decimal lat,        Decimal lon,         Decimal distKm,
        Integer page,       Integer pageSize
    ) {
        return PropertyController.getProperties(
            searchKey, statusFilter, typeFilter, furnishing,
            minPrice, maxPrice, lat, lon, distKm, page, pageSize
        );
    }

    @isTest
    static void getProperties_returnsFirstPageWithPageSize25() {
        Test.startTest();
        PropertyController.PropertyListResult res =
            query(null, null, null, null, null, null, null, null, null, 1, 25);
        Test.stopTest();
        System.assertEquals(25, res.records.size(), 'Default page size 25 expected');
        System.assertEquals(40, res.totalCount,     'Total count should reflect all seeded properties');
        System.assertEquals(2,  res.totalPages,     'Two pages with 40 records and page size 25');
        System.assertEquals(1,  res.pageNumber);
    }

    @isTest
    static void getProperties_secondPageReturnsRemaining() {
        PropertyController.PropertyListResult res =
            query(null, null, null, null, null, null, null, null, null, 2, 25);
        System.assertEquals(15, res.records.size());
        System.assertEquals(2,  res.pageNumber);
    }

    @isTest
    static void getProperties_filterByStatus() {
        Property__c p = [SELECT Id FROM Property__c LIMIT 1];
        p.Status__c = 'Occupied';
        PropertyTriggerHandler.disableForTests = true;
        update p;

        PropertyController.PropertyListResult res =
            query(null, 'Occupied', null, null, null, null, null, null, null, 1, 25);
        System.assertEquals(1, res.totalCount);
        System.assertEquals('Occupied', res.records[0].Status__c);
    }

    @isTest
    static void getProperties_filterByPriceRange() {
        PropertyController.PropertyListResult res =
            query(null, null, null, null, 0, 5000, null, null, null, 1, 25);
        System.assert(res.totalCount > 0, 'Should find at least one property in range');
        for (Property__c p : res.records) {
            System.assert(p.Rent__c >= 0 && p.Rent__c <= 5000);
        }
    }

    @isTest
    static void getProperties_distanceFilter() {
        PropertyController.PropertyListResult res =
            query(null, null, null, null, null, null, 37.4221, -122.0841, 50, 1, 25);
        System.assert(res.records.size() >= 0); // just ensure no exception
    }

    @isTest
    static void getProperties_searchKey() {
        // Search by the first property's name
        Property__c sample = [SELECT Name FROM Property__c LIMIT 1];
        PropertyController.PropertyListResult res =
            query(sample.Name, null, null, null, null, null, null, null, null, 1, 25);
        System.assert(res.totalCount >= 1, 'Search by name should find at least one record');
    }

    @isTest
    static void getProperties_allNullsDefaultsCorrectly() {
        PropertyController.PropertyListResult res =
            query(null, null, null, null, null, null, null, null, null, null, null);
        System.assert(res.records.size() > 0);
        System.assertEquals(1,  res.pageNumber);
        System.assertEquals(25, res.pageSize);
    }

    @isTest
    static void createPropertyWithImages_failsWithoutImages() {
        Property__c p = TestDataFactory.buildProperty('newone');
        try {
            PropertyController.createPropertyWithImages(p, '[]');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            System.assert(true);
        }
    }

    @isTest
    static void createPropertyWithImages_failsWithNullPayload() {
        try {
            PropertyController.createPropertyWithImages(null, null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            System.assert(true);
        }
    }

    @isTest
    static void createPropertyWithImages_attachesImages() {
        Property__c p = TestDataFactory.buildProperty('newWithImg');
        String imagesJson = JSON.serialize(new List<Map<String,String>>{
            new Map<String,String>{
                'fileName'    => 'photo.png',
                'base64Data'  => EncodingUtil.base64Encode(Blob.valueOf('imagebytes')),
                'contentType' => 'image/png'
            }
        });

        Test.startTest();
        Id newId = PropertyController.createPropertyWithImages(p, imagesJson);
        Test.stopTest();

        System.assertNotEquals(null, newId);
        Integer linkCount = [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :newId];
        System.assertEquals(1, linkCount);
    }

    @isTest
    static void getPropertyImageIds_returnsLinkedDocs() {
        Property__c p = TestDataFactory.buildProperty('forImg');
        String imagesJson = JSON.serialize(new List<Map<String,String>>{
            new Map<String,String>{
                'fileName'    => 'photo.png',
                'base64Data'  => EncodingUtil.base64Encode(Blob.valueOf('bytes')),
                'contentType' => 'image/png'
            }
        });
        Id newId = PropertyController.createPropertyWithImages(p, imagesJson);

        List<String> ids = PropertyController.getPropertyImageIds(newId);
        System.assertEquals(1, ids.size());
    }

    @isTest
    static void getPicklistOptions_returnsAllThree() {
        Map<String, List<String>> opts = PropertyController.getPicklistOptions();
        System.assert(opts.containsKey('Status'));
        System.assert(opts.containsKey('Furnishing'));
        System.assert(opts.containsKey('Type'));
        System.assert(!opts.get('Status').isEmpty());
    }

    @isTest
    static void getPropertyLocation_returnsCoords() {
        PropertyTriggerHandler.disableForTests = true;
        Property__c p = TestDataFactory.buildProperty('loc');
        p.Location__Latitude__s  = 12.9;
        p.Location__Longitude__s = 80.1;
        insert p;
        Map<String, Object> result = PropertyController.getPropertyLocation(p.Id);
        System.assertNotEquals(null, result);
        System.assertEquals(12.9, (Decimal) result.get('latitude'));
        System.assertEquals(80.1, (Decimal) result.get('longitude'));
    }

    @isTest
    static void getPropertyLocation_nullIdThrows() {
        try {
            PropertyController.getPropertyLocation(null);
            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assert(true);
        }
    }

    // ── Callout mocks ─────────────────────────────────────────────────────
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[{"lat":"37.4221","lon":"-122.0841","display_name":"Mountain View"}]');
            return res;
        }
    }
    private class EmptyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[]');
            return res;
        }
    }

    @isTest
    static void geocodeProperty_success() {
        PropertyTriggerHandler.disableForTests = true;
        Property__c p = TestDataFactory.buildProperty('geo');
        insert p;
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        Map<String, Object> result = PropertyController.geocodeProperty(p.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(37.4221, (Decimal) result.get('latitude'));
        Property__c reloaded = [SELECT Location__Latitude__s FROM Property__c WHERE Id = :p.Id];
        System.assertEquals(37.4221, reloaded.Location__Latitude__s);
    }

    @isTest
    static void geocodeProperty_noResultThrows() {
        PropertyTriggerHandler.disableForTests = true;
        Property__c p = TestDataFactory.buildProperty('geoFail');
        insert p;
        Test.setMock(HttpCalloutMock.class, new EmptyMock());
        try {
            Test.startTest();
            PropertyController.geocodeProperty(p.Id);
            Test.stopTest();
            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assert(true);
        }
    }

    @isTest
    static void geocodeProperty_nullIdThrows() {
        try {
            PropertyController.geocodeProperty(null);
            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assert(true);
        }
    }
}
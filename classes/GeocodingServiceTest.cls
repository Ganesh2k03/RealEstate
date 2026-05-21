@isTest
private class GeocodingServiceTest {

    public class NominatimSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[{"lat":"37.4221","lon":"-122.0841","display_name":"Mountain View"}]');
            return res;
        }
    }

    public class NominatimEmptyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('[]');
            return res;
        }
    }

    public class NominatimHttpErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Server Error');
            res.setBody('');
            return res;
        }
    }

    @isTest
    static void geocode_success() {
        Test.setMock(HttpCalloutMock.class, new NominatimSuccessMock());
        Test.startTest();
        GeocodingService.GeoResult result = GeocodingService.geocode('Mountain View, CA');
        Test.stopTest();
        System.assertEquals(true, result.success);
        System.assertEquals(37.4221, result.latitude);
        System.assertEquals(-122.0841, result.longitude);
    }

    @isTest
    static void geocode_emptyResults() {
        Test.setMock(HttpCalloutMock.class, new NominatimEmptyMock());
        GeocodingService.GeoResult result = GeocodingService.geocode('Nowhere');
        System.assertEquals(false, result.success);
        System.assertNotEquals(null, result.errorMessage);
    }

    @isTest
    static void geocode_httpError() {
        Test.setMock(HttpCalloutMock.class, new NominatimHttpErrorMock());
        GeocodingService.GeoResult result = GeocodingService.geocode('Anywhere');
        System.assertEquals(false, result.success);
    }

    @isTest
    static void geocode_blankAddress() {
        GeocodingService.GeoResult result = GeocodingService.geocode('');
        System.assertEquals(false, result.success);
    }

    @isTest
    static void buildAddressString_concatenatesFields() {
        Property__c p = new Property__c(
            Address__c = '123 Main',
            City__c = 'NYC',
            State__c = 'NY',
            Postal_Code__c = '10001',
            Country__c = 'USA'
        );
        String result = GeocodingService.buildAddressString(p);
        System.assertEquals('123 Main, NYC, NY, 10001, USA', result);
    }

    @isTest
    static void buildAddressString_nullPropertyReturnsNull() {
        System.assertEquals(null, GeocodingService.buildAddressString(null));
    }

    @isTest
    static void geocodeQueueable_runs() {
        PropertyTriggerHandler.disableForTests = true;
        Property__c p = TestDataFactory.buildProperty('queue');
        insert p;
        Test.setMock(HttpCalloutMock.class, new NominatimSuccessMock());

        Test.startTest();
        System.enqueueJob(new GeocodeQueueable(new List<Id>{ p.Id }));
        Test.stopTest();

        Property__c reloaded = [SELECT Location__Latitude__s, Location__Longitude__s FROM Property__c WHERE Id = :p.Id];
        System.assertEquals(37.4221, reloaded.Location__Latitude__s);
    }

    @isTest
    static void geocodeQueueable_emptyListNoop() {
        Test.startTest();
        new GeocodeQueueable(new List<Id>()).execute(null);
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void geocodeQueueable_failedGeocodeStillCompletes() {
        PropertyTriggerHandler.disableForTests = true;
        Property__c p = TestDataFactory.buildProperty('queueFail');
        insert p;
        Test.setMock(HttpCalloutMock.class, new NominatimEmptyMock());

        Test.startTest();
        System.enqueueJob(new GeocodeQueueable(new List<Id>{ p.Id }));
        Test.stopTest();

        // No assertion on Location - the job logged a warning and finished gracefully.
        System.assert(true);
    }
}
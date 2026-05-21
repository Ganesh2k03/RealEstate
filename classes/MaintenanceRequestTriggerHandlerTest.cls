@isTest
private class MaintenanceRequestTriggerHandlerTest {

    @isTest
    static void newRequestAutoAssignsLeastLoadedVendor() {
        PropertyTriggerHandler.disableForTests = true;
        Property__c p = TestDataFactory.buildProperty('m');
        insert p;
        Vendor__c v1 = TestDataFactory.createVendor('V1');
        Vendor__c v2 = TestDataFactory.createVendor('V2');
        // pre-assign 2 open requests to v1 so v2 is least loaded
        List<Maintenance_Request__c> seed = new List<Maintenance_Request__c>{
            new Maintenance_Request__c(Property__c = p.Id, Vendor__c = v1.Id, Status__c = 'Open'),
            new Maintenance_Request__c(Property__c = p.Id, Vendor__c = v1.Id, Status__c = 'In Progress')
        };
        insert seed;

        Test.startTest();
        Maintenance_Request__c m = new Maintenance_Request__c(Property__c = p.Id, Status__c = 'Open');
        insert m;
        Test.stopTest();

        Maintenance_Request__c reloaded = [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :m.Id];
        System.assertEquals(v2.Id, reloaded.Vendor__c, 'Least-loaded vendor v2 should be assigned');
    }

    @isTest
    static void bulkInsertSpreadsAssignments() {
        PropertyTriggerHandler.disableForTests = true;
        Property__c p = TestDataFactory.buildProperty('bm');
        insert p;
        for (Integer i = 0; i < 3; i++) {
            TestDataFactory.createVendor('VV' + i);
        }
        List<Maintenance_Request__c> requests = new List<Maintenance_Request__c>();
        for (Integer i = 0; i < 30; i++) {
            requests.add(new Maintenance_Request__c(Property__c = p.Id, Status__c = 'Open'));
        }
        Test.startTest();
        insert requests;
        Test.stopTest();
        Map<Id, Integer> distribution = new Map<Id, Integer>();
        for (AggregateResult ar : [SELECT Vendor__c v, COUNT(Id) cnt FROM Maintenance_Request__c WHERE Property__c = :p.Id GROUP BY Vendor__c]) {
            distribution.put((Id) ar.get('v'), (Integer) ar.get('cnt'));
        }
        System.assertEquals(3, distribution.size(), 'All three vendors should have requests assigned');
        for (Integer count : distribution.values()) {
            System.assert(count >= 8 && count <= 12, 'Each vendor gets roughly equal share (got ' + count + ')');
        }
    }

    @isTest
    static void existingVendorAssignmentRespected() {
        PropertyTriggerHandler.disableForTests = true;
        Property__c p = TestDataFactory.buildProperty('rm');
        insert p;
        Vendor__c v = TestDataFactory.createVendor('only');
        Maintenance_Request__c m = new Maintenance_Request__c(
            Property__c = p.Id, Vendor__c = v.Id, Status__c = 'Open'
        );
        insert m;
        Maintenance_Request__c reloaded = [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :m.Id];
        System.assertEquals(v.Id, reloaded.Vendor__c);
    }

    @isTest
    static void noVendorsLeavesVendorBlank() {
        PropertyTriggerHandler.disableForTests = true;
        Property__c p = TestDataFactory.buildProperty('nv');
        insert p;
        Maintenance_Request__c m = new Maintenance_Request__c(Property__c = p.Id, Status__c = 'Open');
        insert m;
        Maintenance_Request__c reloaded = [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :m.Id];
        System.assertEquals(null, reloaded.Vendor__c);
    }
}
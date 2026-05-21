@isTest
private class PropertyTriggerHandlerTest {

    @isTest
    static void bulkInsert_isSafe() {
        // The handler intentionally skips enqueueing in tests. We just need to confirm
        // a 200-record insert succeeds without limit exceptions.
        List<Property__c> props = new List<Property__c>();
        for (Integer i = 0; i < 200; i++) {
            props.add(TestDataFactory.buildProperty('bulk' + i));
        }
        Test.startTest();
        insert props;
        Test.stopTest();
        System.assertEquals(200, [SELECT COUNT() FROM Property__c]);
    }

    @isTest
    static void update_addressChangeDoesNotFail() {
        Property__c p = TestDataFactory.buildProperty('upd');
        insert p;
        p.City__c = 'San Francisco';
        Test.startTest();
        update p;
        Test.stopTest();
        Property__c reloaded = [SELECT City__c FROM Property__c WHERE Id = :p.Id];
        System.assertEquals('San Francisco', reloaded.City__c);
    }

    @isTest
    static void update_nonAddressChangeDoesNotFail() {
        Property__c p = TestDataFactory.buildProperty('upd2');
        insert p;
        p.Status__c = 'Occupied';
        Test.startTest();
        update p;
        Test.stopTest();
        Property__c reloaded = [SELECT Status__c FROM Property__c WHERE Id = :p.Id];
        System.assertEquals('Occupied', reloaded.Status__c);
    }
}
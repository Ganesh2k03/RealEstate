@isTest
private class PropertyTenantTriggerTest {

    @isTest
    static void newAssignmentCreatesTask() {
        PropertyTriggerHandler.disableForTests = true;
        Property__c p = TestDataFactory.buildProperty('pta');
        insert p;
        Tenant__c t = TestDataFactory.createTenant('A');
        Test.startTest();
        insert new Property_Tenant__c(Property__c = p.Id, Tenant__c = t.Id);
        Test.stopTest();
        List<Task> tasks = [SELECT Id, Subject, WhatId, Priority FROM Task WHERE WhatId = :p.Id];
        System.assertEquals(1, tasks.size());
        System.assertEquals('High', tasks[0].Priority);
        System.assert(tasks[0].Subject.contains('Generate Lease Agreement'));
    }

    @isTest
    static void bulkInsertCreatesTasksInOneDml() {
        PropertyTriggerHandler.disableForTests = true;
        Property__c p = TestDataFactory.buildProperty('ptb');
        insert p;
        List<Tenant__c> tenants = new List<Tenant__c>();
        for (Integer i = 0; i < 50; i++) {
            tenants.add(new Tenant__c(Name = 'BT' + i, Email__c = 'bt' + i + '@x.com'));
        }
        insert tenants;
        List<Property_Tenant__c> links = new List<Property_Tenant__c>();
        for (Tenant__c t : tenants) {
            links.add(new Property_Tenant__c(Property__c = p.Id, Tenant__c = t.Id));
        }
        Test.startTest();
        insert links;
        Test.stopTest();
        Integer taskCount = [SELECT COUNT() FROM Task WHERE WhatId = :p.Id];
        System.assertEquals(50, taskCount);
    }
}
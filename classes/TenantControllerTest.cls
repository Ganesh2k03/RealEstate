@isTest
private class TenantControllerTest {

    @isTest
    static void assignPropertyToTenant_createsJunction() {
        PropertyTriggerHandler.disableForTests = true;
        Property__c p = TestDataFactory.buildProperty('aa');
        insert p;
        Tenant__c t = TestDataFactory.createTenant('A');
        Test.startTest();
        Id linkId = TenantController.assignPropertyToTenant(p.Id, t.Id);
        Test.stopTest();
        System.assertNotEquals(null, linkId);
        Integer taskCount = [SELECT COUNT() FROM Task WHERE WhatId = :p.Id];
        System.assertEquals(1, taskCount);
    }

    @isTest
    static void assignPropertyToTenant_nullsThrow() {
        try {
            TenantController.assignPropertyToTenant(null, null);
            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assert(true);
        }
    }
}
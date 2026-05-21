/**
 * Trigger handler for Property_Tenant__c.
 * On insert, creates a Task "Generate Lease Agreement" for each new
 * property/tenant assignment, linked to the property record so it shows
 * up in its activity timeline. Bulk-safe: one DML for the full batch.
 */
public with sharing class PropertyTenantTriggerHandler {

    public static void handleAfterInsert(List<Property_Tenant__c> newList) {
        Set<Id> propertyIds = new Set<Id>();
        Set<Id> tenantIds = new Set<Id>();
        for (Property_Tenant__c pt : newList) {
            if (pt.Property__c != null) propertyIds.add(pt.Property__c);
            if (pt.Tenant__c != null) tenantIds.add(pt.Tenant__c);
        }
        Map<Id, Property__c> properties = new Map<Id, Property__c>([
            SELECT Id, Name FROM Property__c WHERE Id IN :propertyIds
        ]);
        Map<Id, Tenant__c> tenants = new Map<Id, Tenant__c>([
            SELECT Id, Name FROM Tenant__c WHERE Id IN :tenantIds
        ]);

        List<Task> tasks = new List<Task>();
        Date dueDate = Date.today().addDays(7);
        for (Property_Tenant__c pt : newList) {
            Property__c prop = properties.get(pt.Property__c);
            Tenant__c tenant = tenants.get(pt.Tenant__c);
            String propName = prop == null ? '' : prop.Name;
            String tenantName = tenant == null ? '' : tenant.Name;
            Task t = new Task();
            t.Subject = 'Generate Lease Agreement for ' + propName;
            t.Description = 'A property (' + propName + ') has been assigned to tenant '
                + tenantName + '. Please generate the corresponding lease agreement.';
            t.WhatId = pt.Property__c;
            t.OwnerId = pt.OwnerId == null ? UserInfo.getUserId() : pt.OwnerId;
            t.Priority = 'High';
            t.Status = 'Not Started';
            t.ActivityDate = dueDate;
            tasks.add(t);
        }
        if (!tasks.isEmpty()) {
            insert tasks;
        }
    }
}
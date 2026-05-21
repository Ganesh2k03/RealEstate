/**
 * Trigger handler for Maintenance_Request__c.
 * Auto-assigns each new request to the vendor with the lowest current
 * active (Open / In Progress) workload. All counts are loaded in a single
 * aggregate SOQL so the assignment is bulk-safe for inserts up to the
 * 200-record trigger batch.
 */
public with sharing class MaintenanceRequestTriggerHandler {

    public static void handleBeforeInsert(List<Maintenance_Request__c> newList) {
        List<Maintenance_Request__c> toAssign = new List<Maintenance_Request__c>();
        for (Maintenance_Request__c m : newList) {
            if (m.Vendor__c == null) {
                toAssign.add(m);
            }
        }
        if (toAssign.isEmpty()) return;

        Map<Id, Integer> vendorWorkload = loadVendorWorkload();
        if (vendorWorkload.isEmpty()) return;

        for (Maintenance_Request__c m : toAssign) {
            Id chosen = pickLeastLoaded(vendorWorkload);
            if (chosen == null) {
                continue;
            }
            m.Vendor__c = chosen;
            vendorWorkload.put(chosen, vendorWorkload.get(chosen) + 1);
        }
    }

    /** Returns a map of all vendor Ids with their current active workload count. */
    private static Map<Id, Integer> loadVendorWorkload() {
        Map<Id, Integer> workload = new Map<Id, Integer>();
        for (Vendor__c v : [SELECT Id FROM Vendor__c]) {
            workload.put(v.Id, 0);
        }
        for (AggregateResult ar : [
            SELECT Vendor__c vendorId, COUNT(Id) cnt
            FROM Maintenance_Request__c
            WHERE Vendor__c != NULL AND Status__c IN ('Open', 'In Progress')
            GROUP BY Vendor__c
        ]) {
            Id vId = (Id) ar.get('vendorId');
            Integer c = (Integer) ar.get('cnt');
            if (workload.containsKey(vId)) {
                workload.put(vId, c);
            }
        }
        return workload;
    }

    private static Id pickLeastLoaded(Map<Id, Integer> workload) {
        Id chosen;
        Integer minCount = 2147483647;
        for (Id vId : workload.keySet()) {
            Integer c = workload.get(vId);
            if (c < minCount) {
                minCount = c;
                chosen = vId;
            }
        }
        return chosen;
    }
}
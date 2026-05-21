/**
 * Trigger handler for Property__c.
 * Enqueues a geocoding job whenever address fields change.
 * Bulk-safe: collects all property Ids in a single Set, enqueues once.
 */
public with sharing class PropertyTriggerHandler {

    public static Boolean disableForTests = false;

    public static void handleAfterInsert(List<Property__c> newList) {
        if (disableForTests) return;
        Set<Id> toGeocode = new Set<Id>();
        for (Property__c p : newList) {
            if (hasAddress(p)) {
                toGeocode.add(p.Id);
            }
        }
        enqueueGeocode(toGeocode);
    }

    public static void handleAfterUpdate(List<Property__c> newList, Map<Id, Property__c> oldMap) {
        if (disableForTests) return;
        Set<Id> toGeocode = new Set<Id>();
        for (Property__c p : newList) {
            Property__c oldP = oldMap.get(p.Id);
            if (oldP == null) continue;
            if (hasAddress(p) && (
                p.Address__c != oldP.Address__c
                || p.City__c != oldP.City__c
                || p.State__c != oldP.State__c
                || p.Postal_Code__c != oldP.Postal_Code__c
                || p.Country__c != oldP.Country__c
            )) {
                toGeocode.add(p.Id);
            }
        }
        enqueueGeocode(toGeocode);
    }

    private static Boolean hasAddress(Property__c p) {
        return String.isNotBlank(p.Address__c)
            && String.isNotBlank(p.City__c)
            && String.isNotBlank(p.Country__c);
    }

    private static void enqueueGeocode(Set<Id> ids) {
        if (ids.isEmpty()) return;
        if (Test.isRunningTest()) {
            // Avoid enqueueing async work during tests.
            return;
        }
        try {
            System.enqueueJob(new GeocodeQueueable(ids));
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'Could not enqueue geocode: ' + ex.getMessage());
        }
    }
}
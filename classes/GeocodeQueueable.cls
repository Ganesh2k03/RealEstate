/**
 * Async wrapper that geocodes a set of Property__c records and updates
 * their Location__c geolocation field. Invoked from PropertyTriggerHandler
 * so the callout never blocks the DML transaction.
 *
 * Nominatim's usage policy requires 1 request/second, so we process one
 * Property per Queueable execution and chain a new Queueable for the next
 * record. The chain stops when the queue is empty.
 */
public with sharing class GeocodeQueueable implements Queueable, Database.AllowsCallouts {

    private final List<Id> propertyIds;

    public GeocodeQueueable(List<Id> propertyIds) {
        this.propertyIds = propertyIds == null ? new List<Id>() : propertyIds;
    }

    public GeocodeQueueable(Set<Id> idSet) {
        this(new List<Id>(idSet));
    }

    public void execute(QueueableContext ctx) {
        if (propertyIds.isEmpty()) {
            return;
        }
        Id currentId = propertyIds.remove(0);
        List<Property__c> records = [
            SELECT Id, Address__c, City__c, State__c, Postal_Code__c, Country__c
            FROM Property__c
            WHERE Id = :currentId
            LIMIT 1
        ];
        if (records.isEmpty()) {
            chainNext();
            return;
        }
        Property__c prop = records[0];
        String addressString = GeocodingService.buildAddressString(prop);
        GeocodingService.GeoResult geo = GeocodingService.geocode(addressString);
        if (geo.success) {
            Property__c upd = new Property__c(
                Id = prop.Id,
                Location__Latitude__s = geo.latitude,
                Location__Longitude__s = geo.longitude
            );
            update upd;
        } else {
            System.debug(LoggingLevel.WARN, 'Geocoding failed for ' + prop.Id + ': ' + geo.errorMessage);
        }
        chainNext();
    }

    private void chainNext() {
        if (propertyIds.isEmpty()) {
            return;
        }
        if (!Test.isRunningTest()) {
            System.enqueueJob(new GeocodeQueueable(propertyIds));
        }
    }
}
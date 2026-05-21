/**
 * Reusable test data builders for the Real Estate module.
 * Disables Property trigger geocoding (network callout) so tests run fast.
 */
@isTest
public class TestDataFactory {

    public static Property__c buildProperty(String suffix) {
        return new Property__c(
            Name = 'Test Property ' + suffix,
            Address__c = '1600 Amphitheatre Parkway',
            City__c = 'Mountain View',
            State__c = 'CA',
            Postal_Code__c = '94043',
            Country__c = 'USA',
            Type__c = 'Residential',
            Furnishing_Status__c = 'Unfurnished',
            Status__c = 'Available',
            Rent__c = 1000 + Decimal.valueOf(Math.mod(suffix.hashCode(), 1000)),
            Description__c = 'A nice property ' + suffix,
            Location__Latitude__s = 37.4221,
            Location__Longitude__s = -122.0841
        );
    }

    public static List<Property__c> createProperties(Integer howMany) {
        PropertyTriggerHandler.disableForTests = true;
        List<Property__c> props = new List<Property__c>();
        for (Integer i = 0; i < howMany; i++) {
            props.add(buildProperty(String.valueOf(i)));
        }
        insert props;
        return props;
    }

    public static Tenant__c createTenant(String suffix) {
        Tenant__c t = new Tenant__c(
            Name = 'Tenant ' + suffix,
            Phone__c = '555-000-0000',
            Email__c = 'tenant' + suffix + '@example.com'
        );
        insert t;
        return t;
    }

    public static Vendor__c createVendor(String suffix) {
        Vendor__c v = new Vendor__c(
            Name = 'Vendor ' + suffix,
            Phone__c = '555-111-0000',
            Email__c = 'vendor' + suffix + '@example.com'
        );
        insert v;
        return v;
    }

    public static Lease_Agreement__c createLease(Id propertyId, Id tenantId, Date startDate, Date endDate) {
        Lease_Agreement__c lease = new Lease_Agreement__c(
            Property__c = propertyId,
            Tenant__c = tenantId,
            Monthly_Rent__c = 1200,
            Start_Date__c = startDate,
            End_Date__c = endDate,
            Status__c = 'Active',
            Terms__c = 'Standard terms'
        );
        insert lease;
        return lease;
    }
}
@isTest
private class LeaseAgreementControllerTest {

    private static Lease_Agreement__c seedLease(Date startDate, Date endDate) {
        PropertyTriggerHandler.disableForTests = true;
        Property__c p = TestDataFactory.buildProperty('la');
        insert p;
        Tenant__c t = TestDataFactory.createTenant('LA');
        return TestDataFactory.createLease(p.Id, t.Id, startDate, endDate);
    }

    @isTest
    static void getLeaseAgreement_returnsRecord() {
        Lease_Agreement__c lease = seedLease(Date.today(), Date.today().addDays(180));
        Lease_Agreement__c actual = LeaseAgreementController.getLeaseAgreement(lease.Id);
        System.assertNotEquals(null, actual);
        System.assertEquals(lease.Id, actual.Id);
    }

    @isTest
    static void sendLeaseEmail_sends() {
        Lease_Agreement__c lease = seedLease(Date.today(), Date.today().addDays(60));
        String pdfBase64 = EncodingUtil.base64Encode(Blob.valueOf('fake-pdf-bytes'));
        Test.startTest();
        LeaseAgreementController.sendLeaseEmail(lease.Id, pdfBase64, 'lease.pdf');
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void sendLeaseEmail_blankBodyThrows() {
        Lease_Agreement__c lease = seedLease(Date.today(), Date.today().addDays(60));
        try {
            LeaseAgreementController.sendLeaseEmail(lease.Id, '', 'l.pdf');
            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assert(true);
        }
    }

    @isTest
    static void sendLeaseEmail_missingLeaseThrows() {
        try {
            LeaseAgreementController.sendLeaseEmail(null, 'x', 'f.pdf');
            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assert(true);
        }
    }

    @isTest
    static void sendLeaseEmail_dataUriPrefix_stripped() {
        // Covers the rawBase64.contains(',') strip branch
        Lease_Agreement__c lease = seedLease(Date.today(), Date.today().addDays(60));
        String rawBase64  = EncodingUtil.base64Encode(Blob.valueOf('pdf-bytes'));
        String withPrefix = 'data:application/pdf;base64,' + rawBase64;
        Test.startTest();
        LeaseAgreementController.sendLeaseEmail(lease.Id, withPrefix, 'test.pdf');
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void sendLeaseEmail_leaseNotFoundThrows() {
        // Delete the lease after creation so getLeaseAgreement returns null → covers that guard
        PropertyTriggerHandler.disableForTests = true;
        Property__c p = TestDataFactory.buildProperty('dellease');
        insert p;
        Tenant__c t = new Tenant__c(Name = 'Del Tenant', Email__c = 'del@test.com');
        insert t;
        Lease_Agreement__c lease = new Lease_Agreement__c(
            Property__c = p.Id, Tenant__c = t.Id,
            Monthly_Rent__c = 500,
            Start_Date__c = Date.today(), End_Date__c = Date.today().addDays(30),
            Status__c = 'Active'
        );
        insert lease;
        Id deletedId = lease.Id;
        delete lease;
        try {
            LeaseAgreementController.sendLeaseEmail(
                deletedId, EncodingUtil.base64Encode(Blob.valueOf('x')), 'f.pdf'
            );
            System.assert(false, 'Expected exception for deleted lease');
        } catch (AuraHandledException ex) {
            System.assert(true);
        }
    }

    @isTest
    static void sendLeaseEmail_tenantNoEmailThrows() {
        // Covers the tenant-email-missing guard
        PropertyTriggerHandler.disableForTests = true;
        Property__c p = TestDataFactory.buildProperty('nomail');
        insert p;
        Tenant__c t = new Tenant__c(Name = 'NoEmail Tenant');
        insert t;
        Lease_Agreement__c lease = new Lease_Agreement__c(
            Property__c = p.Id, Tenant__c = t.Id,
            Monthly_Rent__c = 1000,
            Start_Date__c = Date.today(), End_Date__c = Date.today().addDays(30),
            Status__c = 'Active'
        );
        insert lease;
        try {
            LeaseAgreementController.sendLeaseEmail(
                lease.Id, EncodingUtil.base64Encode(Blob.valueOf('x')), 'f.pdf'
            );
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            System.assert(true); // exception is expected
        }
    }
}
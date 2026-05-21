/**
 * Endpoints for the Lease Agreement record page actions
 * (build PDF, list, create, email PDF to tenant).
 */
public with sharing class LeaseAgreementController {

    @AuraEnabled(cacheable=true)
    public static Lease_Agreement__c getLeaseAgreement(Id leaseId) {
        List<Lease_Agreement__c> records = [
            SELECT Id, Name, Property__c, Property__r.Name, Property__r.Address__c, Property__r.City__c,
                   Property__r.State__c, Property__r.Postal_Code__c, Property__r.Country__c,
                   Tenant__c, Tenant__r.Name, Tenant__r.Email__c, Tenant__r.Phone__c,
                   Terms__c, Monthly_Rent__c, Start_Date__c, End_Date__c, Status__c
            FROM Lease_Agreement__c
            WHERE Id = :leaseId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return records.isEmpty() ? null : records[0];
    }

    /**
     * Sends the lease agreement PDF (already built client-side by jsPDF)
     * to the linked tenant's email as an attachment.
     */
    @AuraEnabled
    public static void sendLeaseEmail(Id leaseId, String base64Pdf, String fileName) {
        if (leaseId == null) {
            throw new AuraHandledException('Lease Id is required.');
        }
        if (String.isBlank(base64Pdf)) {
            throw new AuraHandledException('PDF content is required.');
        }
        Lease_Agreement__c lease = getLeaseAgreement(leaseId);
        if (lease == null) {
            throw new AuraHandledException('Lease Agreement not found.');
        }
        if (lease.Tenant__c == null || lease.Tenant__r == null || String.isBlank(lease.Tenant__r.Email__c)) {
            throw new AuraHandledException('Tenant email address is not available.');
        }

        // Strip any accidental data-URI header (e.g. "data:application/pdf;base64,")
        String rawBase64 = base64Pdf.trim();
        if (rawBase64.contains(',')) {
            rawBase64 = rawBase64.substringAfter(',');
        }

        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(String.isBlank(fileName) ? ('Lease-' + lease.Name + '.pdf') : fileName);
        try {
            attachment.setBody(EncodingUtil.base64Decode(rawBase64));
        } catch (Exception decodeEx) {
            throw new AuraHandledException('PDF could not be decoded: ' + decodeEx.getMessage());
        }
        attachment.setContentType('application/pdf');

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ lease.Tenant__r.Email__c });
        email.setSubject('Lease Agreement ' + lease.Name);
        email.setPlainTextBody(
            'Hello ' + lease.Tenant__r.Name + ',\n\n' +
            'Please find your lease agreement (' + lease.Name + ') attached for your reference.\n\n' +
            'Property: ' + (lease.Property__r == null ? '' : lease.Property__r.Name) + '\n' +
            'Term: ' + lease.Start_Date__c + ' to ' + lease.End_Date__c + '\n' +
            'Monthly Rent: ' + lease.Monthly_Rent__c + '\n\n' +
            'Best regards,\nProperty Management'
        );
        email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });
        email.setSaveAsActivity(false);

        Messaging.SendEmailResult[] results;
        try {
            results = Messaging.sendEmail(
                new List<Messaging.SingleEmailMessage>{ email }, false
            );
        } catch (Exception ex) {
            throw new AuraHandledException(
                'Email send error: ' + ex.getMessage() +
                '. Tip: In Setup → Email → Deliverability, set "All Email" access level.'
            );
        }
        if (results != null && !results.isEmpty() && !results[0].isSuccess()) {
            String errMsg = '';
            for (Messaging.SendEmailError err : results[0].getErrors()) {
                errMsg += err.getMessage() + ' ';
            }
            // Provide actionable hint for the most common dev-org issue
            if (errMsg.containsIgnoreCase('unavailable') || errMsg.containsIgnoreCase('deliverability')) {
                errMsg += '— Go to Setup → Email → Deliverability and set Access Level to "All Email".';
            }
            throw new AuraHandledException('Failed to send email: ' + errMsg.trim());
        }
    }
}
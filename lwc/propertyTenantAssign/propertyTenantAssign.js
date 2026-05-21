import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import assignPropertyToTenant from '@salesforce/apex/TenantController.assignPropertyToTenant';

export default class PropertyTenantAssign extends LightningElement {
    @api recordId;
    @api objectApiName;
    @track propertyId = '';
    @track tenantId = '';
    @track saving = false;

    connectedCallback() {
        if (this.objectApiName === 'Property__c' && this.recordId) {
            this.propertyId = this.recordId;
        } else if (this.objectApiName === 'Tenant__c' && this.recordId) {
            this.tenantId = this.recordId;
        }
    }

    get propertyLocked() {
        return this.objectApiName === 'Property__c';
    }
    get tenantLocked() {
        return this.objectApiName === 'Tenant__c';
    }

    handlePropertyChange(event) {
        this.propertyId = event.detail.recordId || '';
    }
    handleTenantChange(event) {
        this.tenantId = event.detail.recordId || '';
    }

    get disabled() {
        return this.saving || !this.propertyId || !this.tenantId;
    }

    handleAssign() {
        this.saving = true;
        assignPropertyToTenant({ propertyId: this.propertyId, tenantId: this.tenantId })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Assigned',
                        message: 'Property assigned to tenant. A lease-agreement task has been created.',
                        variant: 'success'
                    })
                );
                if (!this.propertyLocked) this.propertyId = '';
                if (!this.tenantLocked) this.tenantId = '';
            })
            .catch((err) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Assignment failed',
                        message: (err.body && err.body.message) || err.message,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.saving = false;
            });
    }
}
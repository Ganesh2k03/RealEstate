import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createPropertyWithImages from '@salesforce/apex/PropertyController.createPropertyWithImages';
import getPicklistOptions from '@salesforce/apex/PropertyController.getPicklistOptions';

const EMPTY_FORM = () => ({
    Name: '', Address__c: '', City__c: '', State__c: '',
    Postal_Code__c: '', Country__c: '',
    Type__c: 'Residential', Furnishing_Status__c: 'Unfurnished',
    Status__c: 'Available', Rent__c: null, Description__c: ''
});

export default class PropertyCreate extends LightningElement {
    @track form = EMPTY_FORM();
    @track images = [];
    @track statusOptions = [];
    @track furnishingOptions = [];
    @track typeOptions = [];
    @track saving = false;

    @wire(getPicklistOptions)
    wiredPicklists({ data }) {
        if (data) {
            this.statusOptions = this.toOptions(data.Status);
            this.furnishingOptions = this.toOptions(data.Furnishing);
            this.typeOptions = this.toOptions(data.Type);
        }
    }

    toOptions(values) {
        return (values || []).map((v) => ({ label: v, value: v }));
    }

    handleInput(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'number'
            ? (event.target.value === '' ? null : Number(event.target.value))
            : event.target.value;
        this.form = { ...this.form, [field]: value };
    }

    handleComboChange(event) {
        const field = event.target.dataset.field;
        this.form = { ...this.form, [field]: event.detail.value };
    }

    handleFileSelect(event) {
        const files = Array.from(event.target.files || []);
        if (files.length === 0) {
            return;
        }
        const readers = files.map((file) =>
            new Promise((resolve, reject) => {
                const reader = new FileReader();
                reader.onload = () => {
                    const dataUrl = reader.result;
                    // DataURL format: "data:<mime>;base64,<data>"
                    // Find the comma that separates the header from the payload
                    const commaIdx = String(dataUrl).indexOf(',');
                    const base64Data = commaIdx >= 0 ? String(dataUrl).substring(commaIdx + 1) : '';
                    if (!base64Data) {
                        reject(new Error(`Could not read file: ${file.name}`));
                        return;
                    }
                    // Derive MIME from the data URL header when file.type is empty
                    let contentType = file.type;
                    if (!contentType && commaIdx > 0) {
                        const header = String(dataUrl).substring(5, commaIdx); // strip "data:"
                        contentType = header.replace(';base64', '') || 'application/octet-stream';
                    }
                    if (!contentType) {
                        contentType = 'application/octet-stream';
                    }
                    resolve({
                        fileName: file.name,
                        base64Data,
                        contentType
                    });
                };
                reader.onerror = () => reject(new Error(`File read error: ${file.name}`));
                reader.readAsDataURL(file);
            })
        );
        Promise.all(readers)
            .then((items) => {
                this.images = [...this.images, ...items];
            })
            .catch((err) => this.toast('File read error', err.message, 'error'));
    }

    handleRemoveImage(event) {
        const idx = Number(event.currentTarget.dataset.idx);
        this.images = this.images.filter((_, i) => i !== idx);
    }

    get hasImages() {
        return this.images.length > 0;
    }

    get submitDisabled() {
        return this.saving
            || !this.hasImages
            || !this.form.Name
            || !this.form.Address__c
            || !this.form.City__c
            || !this.form.State__c
            || !this.form.Postal_Code__c
            || !this.form.Country__c
            || !this.form.Rent__c
            || !this.form.Description__c;
    }

    handleSubmit() {
        if (this.submitDisabled) {
            this.toast('Missing data', 'Please fill all required fields and attach at least one image.', 'warning');
            return;
        }
        this.saving = true;
        // Serialize images to a JSON string so Apex deserializes manually,
        // avoiding @AuraEnabled camelCase inner-class deserialization issues.
        const imagesJson = JSON.stringify(
            this.images.map((img) => ({
                fileName: img.fileName,
                base64Data: img.base64Data,
                contentType: img.contentType
            }))
        );
        createPropertyWithImages({ prop: { ...this.form }, imagesJson })
            .then(() => {
                this.toast('Property created', 'Property has been saved. The list has been refreshed.', 'success');
                // Reset form + images
                this.form   = EMPTY_FORM();
                this.images = [];
                // Reset the file input so the same file can be re-selected
                const fileInput = this.template.querySelector('input[type="file"]');
                if (fileInput) fileInput.value = '';
                // Notify parent to refresh the list
                this.dispatchEvent(new CustomEvent('created'));
            })
            .catch((err) => {
                this.toast('Save failed', this.reduceError(err), 'error');
            })
            .finally(() => {
                this.saving = false;
            });
    }

    reduceError(error) {
        if (!error) return 'Unknown error';
        if (Array.isArray(error.body)) return error.body.map((e) => e.message).join(', ');
        if (error.body && error.body.message) return error.body.message;
        return error.message || JSON.stringify(error);
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
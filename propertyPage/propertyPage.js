import { LightningElement } from 'lwc';

export default class PropertyPage extends LightningElement {
    // Called when propertyCreate fires the 'created' custom event
    handlePropertyCreated() {
        // Reach into the child c-property-list and call its public @api method
        const list = this.template.querySelector('c-property-list');
        if (list) {
            list.refreshList();
        }
    }
}
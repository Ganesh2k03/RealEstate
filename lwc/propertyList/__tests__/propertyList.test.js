import { createElement } from 'lwc';
import PropertyList from 'c/propertyList';

jest.mock(
    '@salesforce/apex/PropertyController.getProperties',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/PropertyController.getPicklistOptions',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

import getProperties from '@salesforce/apex/PropertyController.getProperties';
import getPicklistOptions from '@salesforce/apex/PropertyController.getPicklistOptions';

const MOCK_RESULT = {
    records: [
        {
            Id: 'a01000000000001',
            Name: 'Prop 1',
            Type__c: 'Residential',
            Status__c: 'Available',
            Furnishing_Status__c: 'Furnished',
            City__c: 'NYC',
            State__c: 'NY',
            Rent__c: 1500
        }
    ],
    totalCount: 1,
    totalPages: 1,
    pageNumber: 1,
    pageSize: 25
};

const MOCK_PICKLIST = {
    Status: ['Available', 'Occupied'],
    Furnishing: ['Furnished', 'Semi-Furnished', 'Unfurnished'],
    Type: ['Residential', 'Commercial']
};

describe('c-property-list', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    function flush() {
        return Promise.resolve();
    }

    it('renders datatable with records emitted via wire', async () => {
        const element = createElement('c-property-list', { is: PropertyList });
        document.body.appendChild(element);
        getPicklistOptions.emit(MOCK_PICKLIST);
        getProperties.emit(MOCK_RESULT);
        await flush();
        const table = element.shadowRoot.querySelector('lightning-datatable');
        expect(table).not.toBeNull();
        expect(table.data.length).toBe(1);
        expect(table.data[0].Name).toBe('Prop 1');
    });

    it('renders pagination labels', async () => {
        const element = createElement('c-property-list', { is: PropertyList });
        document.body.appendChild(element);
        getPicklistOptions.emit(MOCK_PICKLIST);
        getProperties.emit(MOCK_RESULT);
        await flush();
        const text = element.shadowRoot.textContent;
        expect(text).toMatch(/Showing 1-1 of 1/);
    });
});

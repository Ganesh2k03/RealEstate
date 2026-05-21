import { createElement } from 'lwc';
import PropertyCreate from 'c/propertyCreate';
import createPropertyWithImages from '@salesforce/apex/PropertyController.createPropertyWithImages';
import getPicklistOptions from '@salesforce/apex/PropertyController.getPicklistOptions';

jest.mock(
    '@salesforce/apex/PropertyController.createPropertyWithImages',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/PropertyController.getPicklistOptions',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

describe('c-property-create', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    function flush() {
        return Promise.resolve().then(() => Promise.resolve());
    }

    it('disables submit button until form and image are present', async () => {
        getPicklistOptions.mockResolvedValue({
            Status: ['Available'],
            Furnishing: ['Furnished'],
            Type: ['Residential']
        });
        const element = createElement('c-property-create', { is: PropertyCreate });
        document.body.appendChild(element);
        await flush();
        const button = element.shadowRoot.querySelector('lightning-button');
        expect(button.disabled).toBe(true);
    });

    it('rejects submit when no images attached', async () => {
        getPicklistOptions.mockResolvedValue({
            Status: ['Available'],
            Furnishing: ['Furnished'],
            Type: ['Residential']
        });
        const element = createElement('c-property-create', { is: PropertyCreate });
        document.body.appendChild(element);
        await flush();
        const button = element.shadowRoot.querySelector('lightning-button');
        // Submit disabled, so even if we click, createPropertyWithImages shouldn't be called.
        button.click();
        await flush();
        expect(createPropertyWithImages).not.toHaveBeenCalled();
    });
});

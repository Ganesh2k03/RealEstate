import { createElement } from 'lwc';
import PropertyMap from 'c/propertyMap';

jest.mock(
    'lightning/uiRecordApi',
    () => ({
        getRecord: jest.fn(),
        getFieldValue: jest.fn((data, field) => {
            if (data && data.fields && data.fields[field.fieldApiName]) {
                return data.fields[field.fieldApiName].value;
            }
            return null;
        })
    }),
    { virtual: true }
);

describe('c-property-map', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders the card', async () => {
        const element = createElement('c-property-map', { is: PropertyMap });
        element.recordId = 'a01';
        document.body.appendChild(element);
        await Promise.resolve();
        const card = element.shadowRoot.querySelector('lightning-card');
        expect(card).not.toBeNull();
    });
});

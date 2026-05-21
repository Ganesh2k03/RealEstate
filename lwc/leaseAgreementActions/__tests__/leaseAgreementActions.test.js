import { createElement } from 'lwc';
import LeaseAgreementActions from 'c/leaseAgreementActions';
import getLeaseAgreement from '@salesforce/apex/LeaseAgreementController.getLeaseAgreement';
import sendLeaseEmail from '@salesforce/apex/LeaseAgreementController.sendLeaseEmail';

jest.mock(
    '@salesforce/apex/LeaseAgreementController.getLeaseAgreement',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/LeaseAgreementController.sendLeaseEmail',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock(
    'lightning/platformResourceLoader',
    () => ({ loadScript: jest.fn(() => Promise.resolve()) }),
    { virtual: true }
);

const MOCK_LEASE = {
    Id: 'a02000000000001',
    Name: 'LA-00001',
    Status__c: 'Active',
    Monthly_Rent__c: 1500,
    Start_Date__c: '2024-01-01',
    End_Date__c: '2024-12-31',
    Terms__c: 'Standard',
    Property__r: { Name: 'My Prop', Address__c: '1 Main', City__c: 'NYC' },
    Tenant__r: { Name: 'Jane', Email__c: 'jane@example.com', Phone__c: '555' }
};

describe('c-lease-agreement-actions', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    function flush() {
        return Promise.resolve().then(() => Promise.resolve());
    }

    it('renders the two action buttons', async () => {
        getLeaseAgreement.mockResolvedValue(MOCK_LEASE);
        const element = createElement('c-lease-agreement-actions', { is: LeaseAgreementActions });
        element.recordId = MOCK_LEASE.Id;
        document.body.appendChild(element);
        await flush();
        const buttons = element.shadowRoot.querySelectorAll('lightning-button');
        expect(buttons.length).toBe(2);
        expect(buttons[0].label).toBe('Download PDF');
        expect(buttons[1].label).toBe('Send PDF to Tenant');
    });

    it('shows warning toast if jsPDF is not loaded yet', async () => {
        getLeaseAgreement.mockResolvedValue(null);
        const element = createElement('c-lease-agreement-actions', { is: LeaseAgreementActions });
        element.recordId = 'x';
        document.body.appendChild(element);
        await flush();
        const handler = jest.fn();
        element.addEventListener('lightning__showtoast', handler);
        const downloadBtn = element.shadowRoot.querySelectorAll('lightning-button')[0];
        downloadBtn.click();
        await flush();
        expect(handler).toHaveBeenCalled();
    });

    it('does not call sendLeaseEmail when tenant has no email', async () => {
        getLeaseAgreement.mockResolvedValue({ ...MOCK_LEASE, Tenant__r: { Name: 'Jane', Email__c: null } });
        const element = createElement('c-lease-agreement-actions', { is: LeaseAgreementActions });
        element.recordId = MOCK_LEASE.Id;
        document.body.appendChild(element);
        await flush();
        const sendBtn = element.shadowRoot.querySelectorAll('lightning-button')[1];
        sendBtn.click();
        await flush();
        expect(sendLeaseEmail).not.toHaveBeenCalled();
    });
});

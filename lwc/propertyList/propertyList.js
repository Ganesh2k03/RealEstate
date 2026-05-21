import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex }    from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProperties      from '@salesforce/apex/PropertyController.getProperties';
import getPicklistOptions from '@salesforce/apex/PropertyController.getPicklistOptions';

const PAGE_SIZE = 25;

const COLUMNS = [
    { label: 'Name',       fieldName: 'recordUrl', type: 'url',
      typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
    { label: 'Type',       fieldName: 'Type__c' },
    { label: 'Status',     fieldName: 'Status__c' },
    { label: 'Furnishing', fieldName: 'Furnishing_Status__c' },
    { label: 'City',       fieldName: 'City__c' },
    { label: 'State',      fieldName: 'State__c' },
    { label: 'Rent',       fieldName: 'Rent__c', type: 'currency' }
];

export default class PropertyList extends LightningElement {

    // ── Flat @track wire params — each primitive change reliably triggers @wire ──
    @track _searchKey   = '';
    @track _status      = '';
    @track _type        = '';
    @track _furnishing  = '';
    @track _minPrice    = null;
    @track _maxPrice    = null;
    @track _lat         = null;
    @track _lon         = null;
    @track _dist        = null;
    @track _wiredPage   = 1;
    pageSize            = PAGE_SIZE;

    // ── Results ────────────────────────────────────────────────────────────
    @track records     = [];
    @track totalCount  = 0;
    @track totalPages  = 0;
    @track loading     = false;
    wiredResult;

    // ── Local mirror for UI binding ────────────────────────────────────────
    @track _uiMinPrice  = '';
    @track _uiMaxPrice  = '';
    @track _uiDist      = '';

    // ── Picklists ─────────────────────────────────────────────────────────
    @track statusOptions     = [];
    @track furnishingOptions = [];
    @track typeOptions       = [];

    columns = COLUMNS;

    @wire(getPicklistOptions)
    wiredPicklists({ data }) {
        if (data) {
            this.statusOptions     = this.buildOptions(data.Status);
            this.furnishingOptions = this.buildOptions(data.Furnishing);
            this.typeOptions       = this.buildOptions(data.Type);
        }
    }

    // ── Main wire — flat primitive params, always reactive ────────────────
    @wire(getProperties, {
        searchKey       : '$_searchKey',
        statusFilter    : '$_status',
        typeFilter      : '$_type',
        furnishingFilter: '$_furnishing',
        minPrice        : '$_minPrice',
        maxPrice        : '$_maxPrice',
        userLatitude    : '$_lat',
        userLongitude   : '$_lon',
        distanceKm      : '$_dist',
        pageNumber      : '$_wiredPage',
        pageSize        : '$pageSize'
    })
    wiredProperties(result) {
        this.wiredResult = result;
        this.loading = !result.data && !result.error;
        if (result.data) {
            this.records    = (result.data.records || []).map(r => ({
                ...r, recordUrl: '/lightning/r/Property__c/' + r.Id + '/view'
            }));
            this.totalCount = result.data.totalCount;
            this.totalPages = result.data.totalPages;
        } else if (result.error) {
            this.records    = [];
            this.totalCount = 0;
            this.totalPages = 0;
            this.toast('Error loading properties', this.reduceError(result.error), 'error');
        }
    }

    // ── Filter handlers ────────────────────────────────────────────────────
    _searchTimer;

    handleSearchChange(event) {
        const val = event.target.value || '';
        clearTimeout(this._searchTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._searchTimer = setTimeout(() => {
            this._searchKey = val;
            this._wiredPage = 1;
        }, 350);
    }

    handleStatusChange(event) {
        this._status    = event.detail.value || '';
        this._wiredPage = 1;
    }

    handleTypeChange(event) {
        this._type      = event.detail.value || '';
        this._wiredPage = 1;
    }

    handleFurnishingChange(event) {
        this._furnishing = event.detail.value || '';
        this._wiredPage  = 1;
    }

    handleMinPrice(event) {
        const v = event.target.value;
        this._uiMinPrice = v;
        this._minPrice   = (v === '' || v == null) ? null : Number(v);
        this._wiredPage  = 1;
    }

    handleMaxPrice(event) {
        const v = event.target.value;
        this._uiMaxPrice = v;
        this._maxPrice   = (v === '' || v == null) ? null : Number(v);
        this._wiredPage  = 1;
    }

    handleDistanceChange(event) {
        const v = event.target.value;
        this._uiDist    = v;
        this._dist      = (v === '' || v == null) ? null : Number(v);
        this._wiredPage = 1;
    }

    handleUseLocation() {
        if (!navigator.geolocation) {
            this.toast('Unavailable', 'Geolocation not supported.', 'error');
            return;
        }
        navigator.geolocation.getCurrentPosition(
            pos => {
                this._lat       = pos.coords.latitude;
                this._lon       = pos.coords.longitude;
                this._wiredPage = 1;
                this.toast('Location captured', 'Distance filter is now active.', 'success');
            },
            err => this.toast('Location error', err.message, 'error')
        );
    }

    handleResetFilters() {
        // Clear all search timer
        clearTimeout(this._searchTimer);
        // Reset every tracked param — each assignment triggers the wire once
        this._searchKey  = '';
        this._status     = '';
        this._type       = '';
        this._furnishing = '';
        this._minPrice   = null;
        this._maxPrice   = null;
        this._lat        = null;
        this._lon        = null;
        this._dist       = null;
        this._uiMinPrice = '';
        this._uiMaxPrice = '';
        this._uiDist     = '';
        this._wiredPage  = 1;
    }

    // ── Refresh ────────────────────────────────────────────────────────────
    handleRefresh() {
        if (this.wiredResult) return refreshApex(this.wiredResult);
        return null;
    }
    @api refreshList() { return this.handleRefresh(); }

    // ── Pagination ─────────────────────────────────────────────────────────
    get _pageNumber() { return this._wiredPage; }

    handlePrev() {
        if (this._wiredPage > 1) this._wiredPage = this._wiredPage - 1;
    }

    handleNext() {
        if (this._wiredPage < this.totalPages) this._wiredPage = this._wiredPage + 1;
    }

    // ── Getters ─────────────────────────────────────────────────────────────
    get pagingLabel() {
        if (this.totalCount === 0) return 'No properties found';
        const start = (this._wiredPage - 1) * this.pageSize + 1;
        const end   = Math.min(start + this.records.length - 1, this.totalCount);
        return `Showing ${start}–${end} of ${this.totalCount}`;
    }
    get disablePrev() { return this._wiredPage <= 1; }
    get disableNext() { return this._wiredPage >= this.totalPages; }

    buildOptions(values) {
        return [{ label: 'All', value: '' }]
            .concat((values || []).map(v => ({ label: v, value: v })));
    }
    reduceError(err) {
        if (!err) return 'Unknown error';
        if (Array.isArray(err.body)) return err.body.map(e => e.message).join(', ');
        if (err.body && err.body.message) return err.body.message;
        return err.message || JSON.stringify(err);
    }
    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
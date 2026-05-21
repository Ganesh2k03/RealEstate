import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent }       from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import getPropertyLocation      from '@salesforce/apex/PropertyController.getPropertyLocation';
import geocodeProperty          from '@salesforce/apex/PropertyController.geocodeProperty';

export default class PropertyMap extends LightningElement {

    // ── record ID ─────────────────────────────────────────────────────────
    @track _effectiveRecordId;

    @api
    get recordId() { return this._effectiveRecordId; }
    set recordId(value) {
        if (value && value !== this._effectiveRecordId) {
            this._effectiveRecordId = value;
            this._loadLocation(value);
        }
    }

    @wire(CurrentPageReference)
    pageRef(ref) {
        const id = ref && ref.attributes && ref.attributes.recordId;
        if (id && !this._effectiveRecordId) {
            this._effectiveRecordId = id;
            this._loadLocation(id);
        }
    }

    // ── Map state ─────────────────────────────────────────────────────────
    @track markerVar     = [];
    @track mapCenter;
    @track isLoading     = false;
    @track isGeocoding   = false;
    @track errorMessage;

    _loadLocation(propertyId) {
        this.isLoading    = true;
        this.errorMessage = undefined;
        this.markerVar    = [];

        getPropertyLocation({ propertyId })
            .then(data => {
                this.isLoading = false;
                this._buildMarkers(data);
            })
            .catch(err => {
                this.isLoading    = false;
                this.errorMessage = (err.body && err.body.message)
                    ? err.body.message : JSON.stringify(err);
            });
    }

    _buildMarkers(data) {
        if (!data) return;
        const lat  = data.latitude;
        const lon  = data.longitude;
        const name = data.name || 'Property';
        const addr = [data.address, data.city, data.state, data.postalCode, data.country]
                        .filter(Boolean).join(', ');

        if (lat && lon) {
            this.markerVar = [{
                location   : { Latitude: lat, Longitude: lon },
                title      : name,
                description: addr
            }];
            this.mapCenter = { location: { Latitude: lat, Longitude: lon } };
        } else {
            // No coordinates yet — feed the address string so lightning-map tries its own geocoding
            this.markerVar = [{
                location: {
                    Street    : data.address    || '',
                    City      : data.city       || '',
                    State     : data.state      || '',
                    PostalCode: data.postalCode || '',
                    Country   : data.country    || ''
                },
                title      : name,
                description: addr
            }];
            this.mapCenter = undefined;
        }
    }

    // ── Manual geocode button ─────────────────────────────────────────────
    handleRefreshLocation() {
        if (!this._effectiveRecordId || this.isGeocoding) return;
        this.isGeocoding  = true;
        this.errorMessage = undefined;

        geocodeProperty({ propertyId: this._effectiveRecordId })
            .then(data => {
                this.isGeocoding = false;
                this._buildMarkers(data);
                this.dispatchEvent(new ShowToastEvent({
                    title  : 'Location updated',
                    message: `Coordinates set to ${Number(data.latitude).toFixed(4)}, ${Number(data.longitude).toFixed(4)}`,
                    variant: 'success'
                }));
            })
            .catch(err => {
                this.isGeocoding  = false;
                const msg = (err.body && err.body.message) ? err.body.message : JSON.stringify(err);
                this.errorMessage = msg;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Geocoding failed', message: msg, variant: 'error', mode: 'sticky'
                }));
            });
    }

    // ── Template helpers ──────────────────────────────────────────────────
    get showSpinner() { return this.isLoading || this.isGeocoding; }
    get hasMarkers()  { return this.markerVar && this.markerVar.length > 0; }
    get showEmpty()   { return !this.isLoading && !this.hasMarkers && !this.errorMessage; }
    get geocodeBtnLabel() { return this.isGeocoding ? 'Updating…' : 'Refresh Location'; }
    get geocodeBtnDisabled() { return this.isGeocoding || !this._effectiveRecordId; }
}
import { LightningElement, api, wire, track } from 'lwc';
import { CurrentPageReference }            from 'lightning/navigation';
import getPropertyImageIds                 from '@salesforce/apex/PropertyController.getPropertyImageIds';

export default class PropertyImages extends LightningElement {

    @track _effectiveRecordId;
    @track imageUrls   = [];
    @track isLoading   = false;
    @track errorMessage;
    @track activeIndex = 0;   // lightbox: which image is open
    @track lightboxOpen = false;

    @api
    get recordId() { return this._effectiveRecordId; }
    set recordId(value) {
        if (value && value !== this._effectiveRecordId) {
            this._effectiveRecordId = value;
            this._loadImages(value);
        }
    }

    @wire(CurrentPageReference)
    pageRef(ref) {
        const id = ref && ref.attributes && ref.attributes.recordId;
        if (id && !this._effectiveRecordId) {
            this._effectiveRecordId = id;
            this._loadImages(id);
        }
    }

    _loadImages(propertyId) {
        this.isLoading    = true;
        this.errorMessage = undefined;
        getPropertyImageIds({ propertyId })
            .then(ids => {
                this.isLoading = false;
                // Build a renderable list with index and URL
                this.imageUrls = (ids || []).map((docId, idx) => ({
                    idx,
                    key  : docId,
                    // /sfc/servlet.shepherd/document/download/<ContentDocumentId>
                    url  : `/sfc/servlet.shepherd/document/download/${docId}`,
                    alt  : `Property image ${idx + 1}`
                }));
            })
            .catch(err => {
                this.isLoading    = false;
                this.errorMessage = err.body ? err.body.message : JSON.stringify(err);
            });
    }

    // ── Lightbox ──────────────────────────────────────────────────────────
    handleThumbnailClick(event) {
        this.activeIndex = Number(event.currentTarget.dataset.idx);
        this.lightboxOpen = true;
    }

    closeLightbox() {
        this.lightboxOpen = false;
    }

    prevImage() {
        this.activeIndex = (this.activeIndex - 1 + this.imageUrls.length) % this.imageUrls.length;
    }

    nextImage() {
        this.activeIndex = (this.activeIndex + 1) % this.imageUrls.length;
    }

    get activeUrl() {
        return this.imageUrls.length ? this.imageUrls[this.activeIndex].url : '';
    }

    get activeAlt() {
        return this.imageUrls.length ? this.imageUrls[this.activeIndex].alt : '';
    }

    stopProp(event) { event.stopPropagation(); }

    get hasImages()  { return this.imageUrls.length > 0; }
    get showEmpty()  { return !this.isLoading && !this.hasImages && !this.errorMessage; }
    get imageCount() { return this.imageUrls.length; }
}
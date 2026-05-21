import { LightningElement, api, wire, track } from 'lwc';
import { loadScript }           from 'lightning/platformResourceLoader';
import { ShowToastEvent }       from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import JSPDF                    from '@salesforce/resourceUrl/jsPDF';
import LOGO_URL                 from '@salesforce/resourceUrl/REState_logo';
import getLeaseAgreement        from '@salesforce/apex/LeaseAgreementController.getLeaseAgreement';
import sendLeaseEmail           from '@salesforce/apex/LeaseAgreementController.sendLeaseEmail';

export default class LeaseAgreementActions extends LightningElement {

    // ── Record ID ─────────────────────────────────────────────────────────
    @track _effectiveRecordId;
    @track lease;
    @track loading  = false;
    @track leaseErr;
    libLoaded = false;
    _logoBase64 = null;

    @api
    get recordId() { return this._effectiveRecordId; }
    set recordId(value) {
        if (value && value !== this._effectiveRecordId) {
            this._effectiveRecordId = value;
            this._loadLease(value);
        }
    }

    @wire(CurrentPageReference)
    pageRef(ref) {
        const id = ref && ref.attributes && ref.attributes.recordId;
        if (id && !this._effectiveRecordId) {
            this._effectiveRecordId = id;
            this._loadLease(id);
        }
    }

    _loadLease(leaseId) {
        this.leaseErr = undefined;
        getLeaseAgreement({ leaseId })
            .then(data  => { this.lease = data; })
            .catch(err  => { this.leaseErr = this.reduceError(err); });
    }

    // ── Load jsPDF + pre-fetch logo as base64 ────────────────────────────
    renderedCallback() {
        if (this.libLoaded) return;
        this.libLoaded = true;
        loadScript(this, JSPDF + '/jspdf.umd.min.js')
            .then(() => this._fetchLogo())
            .catch(err => {
                this.libLoaded = false;
                this.toast('jsPDF load failed', err.message || String(err), 'error');
            });
    }

    _fetchLogo() {
        return fetch(LOGO_URL)
            .then(r => r.blob())
            .then(blob => new Promise(resolve => {
                const reader = new FileReader();
                reader.onloadend = () => resolve(reader.result);
                reader.readAsDataURL(blob);
            }))
            .then(dataUrl => { this._logoBase64 = dataUrl; })
            .catch(() => { this._logoBase64 = null; }); // logo is optional
    }

    // ── PDF Builder ───────────────────────────────────────────────────────
    _buildPdf() {
        const jsPDFLib = (window.jspdf && window.jspdf.jsPDF) || window.jsPDF;
        if (!jsPDFLib) throw new Error('jsPDF not loaded yet. Try again in a moment.');

        const doc    = new jsPDFLib({ unit: 'pt', format: 'a4' });
        const W      = doc.internal.pageSize.getWidth();
        const H      = doc.internal.pageSize.getHeight();
        const ML     = 48;   // margin left
        const MR     = W - 48; // margin right
        const BLUE   = [0, 70, 180];
        const DGRAY  = [60, 60, 60];
        const LGRAY  = [200, 200, 200];
        const WHITE  = [255, 255, 255];
        const BLACK  = [0, 0, 0];

        const pr = this.lease.Property__r || {};
        const tr = this.lease.Tenant__r   || {};
        const propAddr = [pr.Address__c, pr.City__c, pr.State__c,
                          pr.Postal_Code__c, pr.Country__c].filter(Boolean).join(', ');

        // ── Helper: filled rect ─────────────────────────────────────────
        const fillRect = (x, y, w, h, rgb) => {
            doc.setFillColor(...rgb);
            doc.rect(x, y, w, h, 'F');
        };

        // ── Header bar ──────────────────────────────────────────────────
        fillRect(0, 0, W, 56, BLUE);
        doc.setTextColor(...WHITE);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(20);
        doc.text('LEASE AGREEMENT', ML, 36);

        // Logo (top-right inside header bar)
        if (this._logoBase64) {
            try { doc.addImage(this._logoBase64, 'JPEG', MR - 100, 8, 90, 40); }
            catch (e) { /* ignore logo errors */ }
        }

        let y = 72;

        // ── Agreement meta row ──────────────────────────────────────────
        doc.setTextColor(...DGRAY);
        doc.setFontSize(9);
        doc.setFont('helvetica', 'normal');
        doc.text(`Agreement No : ${this.lease.Name || '—'}`, ML, y);
        doc.text(`Status : ${this.lease.Status__c || '—'}`,  W / 2, y);
        doc.text(`Date : ${new Date().toLocaleDateString('en-IN')}`, MR, y, { align: 'right' });
        y += 18;

        // Thin divider
        doc.setDrawColor(...LGRAY);
        doc.setLineWidth(0.5);
        doc.line(ML, y, MR, y);
        y += 16;

        // ── Two-column info block ───────────────────────────────────────
        const colW = (MR - ML - 12) / 2;
        const colR = ML + colW + 12;

        const infoBlock = (label, lines, x, startY, w) => {
            doc.setFont('helvetica', 'bold');
            doc.setFontSize(9);
            doc.setTextColor(...BLUE);
            doc.text(label, x, startY);
            doc.setFont('helvetica', 'normal');
            doc.setTextColor(...DGRAY);
            doc.setFontSize(9);
            let ly = startY + 13;
            lines.filter(Boolean).forEach(line => {
                const wrapped = doc.splitTextToSize(String(line), w);
                doc.text(wrapped, x, ly);
                ly += wrapped.length * 12;
            });
            return ly;
        };

        const leftEnd  = infoBlock('PROPERTY', [
            pr.Name, propAddr
        ], ML, y, colW);

        const rightEnd = infoBlock('TENANT', [
            tr.Name,
            tr.Email__c ? `Email : ${tr.Email__c}` : null,
            tr.Phone__c ? `Phone : ${tr.Phone__c}` : null
        ], colR, y, colW);

        y = Math.max(leftEnd, rightEnd) + 12;
        doc.line(ML, y, MR, y);
        y += 16;

        // ── Lease Terms Table ────────────────────────────────────────────
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(10);
        doc.setTextColor(...BLUE);
        doc.text('LEASE TERMS', ML, y);
        y += 10;

        const tHeaders = ['Term', 'Details'];
        const tRows    = [
            ['Start Date',    this.lease.Start_Date__c  || '—'],
            ['End Date',      this.lease.End_Date__c    || '—'],
            ['Monthly Rent',  this.lease.Monthly_Rent__c != null
                                ? `₹ ${Number(this.lease.Monthly_Rent__c).toLocaleString('en-IN')}` : '—'],
            ['Status',        this.lease.Status__c      || '—'],
            ['Property Type', pr.Type__c                || '—'],
            ['Furnishing',    pr.Furnishing_Status__c   || '—']
        ];

        const tableX  = ML;
        const tableW  = MR - ML;
        const col0W   = tableW * 0.35;
        const col1W   = tableW * 0.65;
        const rowH    = 20;
        const cellPad = 6;

        // Header row
        fillRect(tableX, y, tableW, rowH, BLUE);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(9);
        doc.setTextColor(...WHITE);
        doc.text(tHeaders[0], tableX + cellPad, y + 13);
        doc.text(tHeaders[1], tableX + col0W + cellPad, y + 13);
        y += rowH;

        tRows.forEach((row, i) => {
            const bg = i % 2 === 0 ? [245, 247, 251] : WHITE;
            fillRect(tableX, y, tableW, rowH, bg);
            doc.setDrawColor(...LGRAY);
            doc.setLineWidth(0.3);
            doc.rect(tableX, y, col0W, rowH);
            doc.rect(tableX + col0W, y, col1W, rowH);
            doc.setFont('helvetica', 'bold');
            doc.setFontSize(9);
            doc.setTextColor(...DGRAY);
            doc.text(row[0], tableX + cellPad, y + 13);
            doc.setFont('helvetica', 'normal');
            doc.text(row[1], tableX + col0W + cellPad, y + 13);
            y += rowH;
        });

        y += 16;

        // ── Additional Terms ─────────────────────────────────────────────
        if (this.lease.Terms__c) {
            doc.setFont('helvetica', 'bold');
            doc.setFontSize(10);
            doc.setTextColor(...BLUE);
            doc.text('ADDITIONAL TERMS & CONDITIONS', ML, y);
            y += 12;
            doc.setFont('helvetica', 'normal');
            doc.setFontSize(9);
            doc.setTextColor(...DGRAY);
            const wrapped = doc.splitTextToSize(this.lease.Terms__c, MR - ML);
            doc.text(wrapped, ML, y);
            y += wrapped.length * 12 + 16;
        }

        // ── Signature section ────────────────────────────────────────────
        // Push to near bottom if space allows
        const sigY = Math.max(y + 20, H - 120);
        doc.setDrawColor(...LGRAY);
        doc.line(ML, sigY, MR, sigY);
        const sigCol = (MR - ML) / 2;

        doc.setFont('helvetica', 'bold');
        doc.setFontSize(9);
        doc.setTextColor(...DGRAY);
        doc.text('Tenant Signature', ML, sigY + 14);
        doc.text('Landlord / Property Manager Signature', ML + sigCol + 12, sigY + 14);

        doc.setFont('helvetica', 'normal');
        doc.setTextColor(150, 150, 150);
        doc.text('Name  : ____________________________', ML, sigY + 30);
        doc.text('Date  : ____________________________', ML, sigY + 46);
        doc.text('Name  : ____________________________', ML + sigCol + 12, sigY + 30);
        doc.text('Date  : ____________________________', ML + sigCol + 12, sigY + 46);

        // ── Footer bar ────────────────────────────────────────────────────
        fillRect(0, H - 28, W, 28, BLUE);
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(8);
        doc.setTextColor(...WHITE);
        doc.text('Real Estate Management System  ·  Confidential', ML, H - 10);
        doc.text(`Page 1 of 1`, MR, H - 10, { align: 'right' });

        return doc;
    }

    // ── Handlers ──────────────────────────────────────────────────────────
    handleDownload() {
        if (!this.lease) { this.toast('Not ready', 'Lease data is still loading.', 'warning'); return; }
        try {
            this._buildPdf().save('Lease-' + this.lease.Name + '.pdf');
        } catch (err) { this.toast('PDF error', err.message, 'error'); }
    }

    handleSend() {
        if (!this.lease) { this.toast('Not ready', 'Lease data is still loading.', 'warning'); return; }
        const email = tr => tr && tr.Email__c;
        if (!email(this.lease.Tenant__r)) {
            this.toast('Missing email', 'Tenant has no email address on file.', 'warning'); return;
        }
        this.loading = true;
        try {
            const doc      = this._buildPdf();
            const dataUri  = doc.output('datauristring');
            const commaIdx = dataUri.indexOf(',');
            const base64   = commaIdx >= 0 ? dataUri.substring(commaIdx + 1) : dataUri;
            const fileName = 'Lease-' + this.lease.Name + '.pdf';

            sendLeaseEmail({ leaseId: this._effectiveRecordId, base64Pdf: base64, fileName })
                .then(() => {
                    this.toast('Email sent ✓',
                        'Lease PDF sent to ' + this.lease.Tenant__r.Email__c, 'success');
                })
                .catch(err => this.toast('Send failed', this.reduceError(err), 'error'))
                .finally(() => { this.loading = false; });
        } catch (err) {
            this.loading = false;
            this.toast('PDF error', err.message, 'error');
        }
    }

    // ── Template helpers ──────────────────────────────────────────────────
    get leaseLoaded()    { return !!this.lease; }
    get buttonsDisabled(){ return !this.lease || this.loading; }
    get showLoadingMsg() { return !this.lease && !this.leaseErr; }
    get tenantEmail()    { return this.lease && this.lease.Tenant__r && this.lease.Tenant__r.Email__c; }

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
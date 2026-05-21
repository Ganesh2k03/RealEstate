/**
 * Server-side endpoints for the Real Estate Property module.
 * Provides paginated, filterable property queries (incl. geo-radius)
 * and creation with mandatory image attachment in one transaction.
 */
public with sharing class PropertyController {

    public static final Integer DEFAULT_PAGE_SIZE = 25;
    public static final Integer MAX_PAGE_SIZE = 200;

    public class PropertyFilter {
        @AuraEnabled public Decimal minPrice;
        @AuraEnabled public Decimal maxPrice;
        @AuraEnabled public String status;
        @AuraEnabled public String furnishingStatus;
        @AuraEnabled public String propertyType;
        @AuraEnabled public String searchKey;
        @AuraEnabled public Decimal userLatitude;
        @AuraEnabled public Decimal userLongitude;
        @AuraEnabled public Decimal distanceKm;
    }

    public class PropertyListResult {
        @AuraEnabled public List<Property__c> records;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Integer totalPages;
    }

    public class ImageInput {
        @AuraEnabled public String fileName;
        @AuraEnabled public String base64Data;
        @AuraEnabled public String contentType;
    }

    /**
     * Returns one page of properties matching the supplied filter.
     * All parameters are flat primitives so that @wire reactivity fires
     * reliably when any single value changes.
     */
    @AuraEnabled(cacheable=true)
    public static PropertyListResult getProperties(
        String  searchKey,
        String  statusFilter,
        String  typeFilter,
        String  furnishingFilter,
        Decimal minPrice,
        Decimal maxPrice,
        Decimal userLatitude,
        Decimal userLongitude,
        Decimal distanceKm,
        Integer pageNumber,
        Integer pageSize
    ) {
        PropertyFilter filter = new PropertyFilter();
        filter.searchKey       = searchKey;
        filter.status          = statusFilter;
        filter.propertyType    = typeFilter;
        filter.furnishingStatus = furnishingFilter;
        filter.minPrice        = minPrice;
        filter.maxPrice        = maxPrice;
        filter.userLatitude    = userLatitude;
        filter.userLongitude   = userLongitude;
        filter.distanceKm      = distanceKm;

        Integer page = (pageNumber == null || pageNumber < 1) ? 1 : pageNumber;
        Integer size = (pageSize == null || pageSize < 1) ? DEFAULT_PAGE_SIZE : Math.min(pageSize, MAX_PAGE_SIZE);
        Integer offset = (page - 1) * size;

        List<String> whereClauses = new List<String>();
        Map<String, Object> binds = new Map<String, Object>();

        if (filter.minPrice != null) {
            whereClauses.add('Rent__c >= :minPrice');
            binds.put('minPrice', filter.minPrice);
        }
        if (filter.maxPrice != null) {
            whereClauses.add('Rent__c <= :maxPrice');
            binds.put('maxPrice', filter.maxPrice);
        }
        if (String.isNotBlank(filter.status)) {
            whereClauses.add('Status__c = :statusVal');
            binds.put('statusVal', filter.status);
        }
        if (String.isNotBlank(filter.furnishingStatus)) {
            whereClauses.add('Furnishing_Status__c = :furnishingVal');
            binds.put('furnishingVal', filter.furnishingStatus);
        }
        if (String.isNotBlank(filter.propertyType)) {
            whereClauses.add('Type__c = :typeVal');
            binds.put('typeVal', filter.propertyType);
        }
        if (String.isNotBlank(filter.searchKey)) {
            whereClauses.add('(Name LIKE :searchPattern OR City__c LIKE :searchPattern OR Address__c LIKE :searchPattern)');
            binds.put('searchPattern', '%' + String.escapeSingleQuotes(filter.searchKey) + '%');
        }
        Boolean useDistance = (filter.userLatitude != null && filter.userLongitude != null && filter.distanceKm != null && filter.distanceKm > 0);
        if (useDistance) {
            whereClauses.add('DISTANCE(Location__c, GEOLOCATION(:lat,:lon), \'km\') < :dist');
            whereClauses.add('Location__Latitude__s != NULL');
            whereClauses.add('Location__Longitude__s != NULL');
            binds.put('lat', filter.userLatitude);
            binds.put('lon', filter.userLongitude);
            binds.put('dist', filter.distanceKm);
        }

        String whereSql = whereClauses.isEmpty() ? '' : ' WHERE ' + String.join(whereClauses, ' AND ');
        String orderSql = useDistance
            ? ' ORDER BY DISTANCE(Location__c, GEOLOCATION(:lat,:lon), \'km\') ASC, Name ASC'
            : ' ORDER BY CreatedDate DESC';

        String fields = 'Id, Name, Address__c, City__c, State__c, Postal_Code__c, Country__c, Type__c, '
            + 'Furnishing_Status__c, Status__c, Rent__c, Description__c, Location__Latitude__s, '
            + 'Location__Longitude__s, CreatedDate';

        String pageQuery = 'SELECT ' + fields + ' FROM Property__c' + whereSql + orderSql
            + ' LIMIT :pageLimit OFFSET :pageOffset';
        binds.put('pageLimit', size);
        binds.put('pageOffset', offset);

        List<Property__c> records = Database.queryWithBinds(
            pageQuery,
            binds,
            AccessLevel.SYSTEM_MODE
        );

        Integer totalCount;
        try {
            String countQuery = 'SELECT COUNT() FROM Property__c' + whereSql;
            totalCount = Database.countQueryWithBinds(countQuery, binds, AccessLevel.SYSTEM_MODE);
        } catch (Exception ex) {
            // Some aggregate combinations with DISTANCE() are not supported.
            // Approximate from current page; UI displays "25+" indicator.
            totalCount = (records != null && records.size() == size) ? (offset + size + 1) : (offset + (records == null ? 0 : records.size()));
        }

        PropertyListResult result = new PropertyListResult();
        result.records = records;
        result.totalCount = totalCount;
        result.pageNumber = page;
        result.pageSize = size;
        result.totalPages = (totalCount == 0) ? 0 : (Integer) Math.ceil((Decimal) totalCount / (Decimal) size);
        return result;
    }

    /**
     * Returns the ContentDocumentIds linked to the property so the UI can
     * render images via /sfc/servlet.shepherd/version/download URLs.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getPropertyImageIds(Id propertyId) {
        List<String> ids = new List<String>();
        for (ContentDocumentLink link : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :propertyId
            WITH SYSTEM_MODE
        ]) {
            ids.add(link.ContentDocumentId);
        }
        return ids;
    }

    /**
     * Creates a Property__c with at least one image attached. The whole
     * operation runs in a single transaction; if any image fails to attach,
     * the property record is rolled back.
     */
    @AuraEnabled
    public static Id createPropertyWithImages(Property__c prop, String imagesJson) {
        if (prop == null) {
            throw new AuraHandledException('Property data is required.');
        }
        if (String.isBlank(imagesJson)) {
            throw new AuraHandledException('At least one property image is required.');
        }

        // Deserialize manually to avoid @AuraEnabled camelCase field-name issues
        List<Object> rawList;
        try {
            rawList = (List<Object>) JSON.deserializeUntyped(imagesJson);
        } catch (Exception e) {
            throw new AuraHandledException('Image data could not be parsed: ' + e.getMessage());
        }
        if (rawList == null || rawList.isEmpty()) {
            throw new AuraHandledException('At least one property image is required.');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            insert prop;

            List<ContentVersion> versions = new List<ContentVersion>();
            for (Object rawImg : rawList) {
                Map<String, Object> img = (Map<String, Object>) rawImg;
                String fileName  = (String) img.get('fileName');
                String base64Data = (String) img.get('base64Data');
                String contentType = (String) img.get('contentType');

                if (String.isBlank(fileName)) {
                    throw new AuraHandledException('An image is missing its filename.');
                }
                if (String.isBlank(base64Data)) {
                    throw new AuraHandledException('Image "' + fileName + '" has no data. Please re-select the file and try again.');
                }
                // Strip any accidental data-URL header that slipped through
                String rawBase64 = base64Data.trim();
                if (rawBase64.contains(',')) {
                    rawBase64 = rawBase64.substringAfter(',');
                }
                Blob imgBlob;
                try {
                    imgBlob = EncodingUtil.base64Decode(rawBase64);
                } catch (Exception decodeEx) {
                    throw new AuraHandledException('Image "' + fileName + '" could not be decoded. Make sure it is a valid image file.');
                }
                ContentVersion cv = new ContentVersion();
                cv.Title = fileName;
                cv.PathOnClient = fileName;
                cv.VersionData = imgBlob;
                cv.IsMajorVersion = true;
                versions.add(cv);
            }
            insert versions;

            Set<Id> versionIds = new Set<Id>();
            for (ContentVersion cv : versions) {
                versionIds.add(cv.Id);
            }
            Map<Id, ContentVersion> reloaded = new Map<Id, ContentVersion>([
                SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :versionIds
            ]);
            List<ContentDocumentLink> links = new List<ContentDocumentLink>();
            for (ContentVersion cv : reloaded.values()) {
                ContentDocumentLink link = new ContentDocumentLink();
                link.ContentDocumentId = cv.ContentDocumentId;
                link.LinkedEntityId = prop.Id;
                link.ShareType = 'V';
                link.Visibility = 'AllUsers';
                links.add(link);
            }
            insert links;
            return prop.Id;
        } catch (Exception ex) {
            Database.rollback(sp);
            if (ex instanceof AuraHandledException) {
                throw ex;
            }
            throw new AuraHandledException('Failed to create property: ' + ex.getMessage());
        }
    }

    /**
     * Returns picklist values for use in the UI without requiring describe round-trips.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getPicklistOptions() {
        Map<String, List<String>> options = new Map<String, List<String>>();
        options.put('Status', getValues(Property__c.Status__c.getDescribe()));
        options.put('Furnishing', getValues(Property__c.Furnishing_Status__c.getDescribe()));
        options.put('Type', getValues(Property__c.Type__c.getDescribe()));
        return options;
    }

    private static List<String> getValues(Schema.DescribeFieldResult dfr) {
        List<String> values = new List<String>();
        for (Schema.PicklistEntry entry : dfr.getPicklistValues()) {
            if (entry.isActive()) {
                values.add(entry.getValue());
            }
        }
        return values;
    }

    /**
     * Geocodes the property's address on-demand from the UI and immediately
     * updates Location__Latitude__s / Location__Longitude__s. Callout is
     * safe here because there is no prior DML in this transaction context.
     */
    @AuraEnabled
    public static Map<String, Object> geocodeProperty(Id propertyId) {
        if (propertyId == null) {
            throw new AuraHandledException('propertyId is required.');
        }
        List<Property__c> rows = [
            SELECT Id, Name, Address__c, City__c, State__c, Postal_Code__c, Country__c
            FROM Property__c WHERE Id = :propertyId WITH SYSTEM_MODE LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new AuraHandledException('Property not found.');
        }
        Property__c prop = rows[0];
        String addressStr = GeocodingService.buildAddressString(prop);
        if (String.isBlank(addressStr)) {
            throw new AuraHandledException('Property has no address to geocode. Please fill in Address, City, and Country.');
        }
        GeocodingService.GeoResult geo = GeocodingService.geocode(addressStr);
        if (!geo.success) {
            throw new AuraHandledException(
                'Geocoding failed: ' + geo.errorMessage +
                '. Try adding more details (street, city, state, country).'
            );
        }
        Property__c upd = new Property__c(
            Id = propertyId,
            Location__Latitude__s  = geo.latitude,
            Location__Longitude__s = geo.longitude
        );
        update upd;

        return new Map<String, Object>{
            'name'      => prop.Name,
            'address'   => prop.Address__c,
            'city'      => prop.City__c,
            'state'     => prop.State__c,
            'postalCode'=> prop.Postal_Code__c,
            'country'   => prop.Country__c,
            'latitude'  => geo.latitude,
            'longitude' => geo.longitude
        };
    }

    /**
     * Returns the property location data needed by the propertyMap component.
     * Runs in SYSTEM_MODE to guarantee the geolocation sub-fields are readable
     * regardless of the running user's FLS settings.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPropertyLocation(Id propertyId) {
        if (propertyId == null) {
            throw new AuraHandledException('propertyId is required.');
        }
        List<Property__c> rows = [
            SELECT Id, Name,
                   Address__c, City__c, State__c, Postal_Code__c, Country__c,
                   Location__Latitude__s, Location__Longitude__s
            FROM Property__c
            WHERE Id = :propertyId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new AuraHandledException('Property not found.');
        }
        Property__c p = rows[0];
        Map<String, Object> result = new Map<String, Object>{
            'name'      => p.Name,
            'address'   => p.Address__c,
            'city'      => p.City__c,
            'state'     => p.State__c,
            'postalCode'=> p.Postal_Code__c,
            'country'   => p.Country__c,
            'latitude'  => p.Location__Latitude__s,
            'longitude' => p.Location__Longitude__s
        };
        return result;
    }
}
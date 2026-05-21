/**
 * Thin wrapper around OpenStreetMap's free Nominatim geocoding service.
 * Returns {latitude, longitude} for a human-readable address string.
 *
 * Nominatim's usage policy requires a descriptive User-Agent header.
 *
 * The callout is synchronous so it can be invoked from a Queueable; the
 * trigger never calls this directly - it enqueues a GeocodeQueueable instead.
 */
public with sharing class GeocodingService {

    @TestVisible
    private static final String NOMINATIM_ENDPOINT = 'https://nominatim.openstreetmap.org/search';
    private static final String USER_AGENT = 'Salesforce-RealEstate-App/1.0';

    public class GeoResult {
        public Decimal latitude;
        public Decimal longitude;
        public Boolean success;
        public String errorMessage;
    }

    public static GeoResult geocode(String address) {
        GeoResult result = new GeoResult();
        result.success = false;
        if (String.isBlank(address)) {
            result.errorMessage = 'Address is blank.';
            return result;
        }
        try {
            String url = NOMINATIM_ENDPOINT
                + '?format=json&limit=1&q='
                + EncodingUtil.urlEncode(address, 'UTF-8');
            HttpRequest req = new HttpRequest();
            req.setEndpoint(url);
            req.setMethod('GET');
            req.setHeader('User-Agent', USER_AGENT);
            req.setHeader('Accept', 'application/json');
            req.setTimeout(60000);

            Http http = new Http();
            HttpResponse res = http.send(req);
            if (res.getStatusCode() != 200) {
                result.errorMessage = 'HTTP ' + res.getStatusCode() + ': ' + res.getStatus();
                return result;
            }
            Object parsed = JSON.deserializeUntyped(res.getBody());
            List<Object> arr = (List<Object>) parsed;
            if (arr == null || arr.isEmpty()) {
                result.errorMessage = 'No results from geocoder.';
                return result;
            }
            Map<String, Object> first = (Map<String, Object>) arr[0];
            result.latitude = Decimal.valueOf((String) first.get('lat'));
            result.longitude = Decimal.valueOf((String) first.get('lon'));
            result.success = true;
            return result;
        } catch (Exception ex) {
            result.errorMessage = ex.getMessage();
            return result;
        }
    }

    public static String buildAddressString(Property__c prop) {
        if (prop == null) {
            return null;
        }
        List<String> parts = new List<String>();
        if (String.isNotBlank(prop.Address__c)) parts.add(prop.Address__c);
        if (String.isNotBlank(prop.City__c)) parts.add(prop.City__c);
        if (String.isNotBlank(prop.State__c)) parts.add(prop.State__c);
        if (String.isNotBlank(prop.Postal_Code__c)) parts.add(prop.Postal_Code__c);
        if (String.isNotBlank(prop.Country__c)) parts.add(prop.Country__c);
        return parts.isEmpty() ? null : String.join(parts, ', ');
    }
}
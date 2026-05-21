**Real Estate Property Management - Salesforce App**

A self-contained Salesforce module that delivers everything from the requirements brief:
property management with paginated/filtered list views, image-required record creation,
geocoding with map display, tenants and lease agreements with PDF generation/email,
vendor management with auto-assigned maintenance requests, scheduled lease-expiry
reminders, and a reporting dashboard.

This module lives entirely within force-app/main/default/ in the existing SFDX project
and does not modify any of the pre-existing metadata in the org. Every component —
classes, triggers, LWCs, objects, flexipages, reports, dashboard, tabs, permission set,
remote site setting, and static resources — is tracked as SFDX source under that path
and can be deployed in isolation via the dedicated manifest at

These are the components I created for the Real Estate application. While working on them, I identified a few suggestions and possible improvements:

* Instead of maintaining Vendor and Tenant as separate objects, we can use a single object with Record Types to differentiate them. This would simplify the data model and allow us to apply lookup filters based on the required purpose wherever the object is referenced.

* Currently, the Property creation is configured directly on the Lightning page. As an improvement, we can introduce a custom List View button for Property creation, remove the standard “New” button, and place the required components within the custom flow/button experience for better usability and control.



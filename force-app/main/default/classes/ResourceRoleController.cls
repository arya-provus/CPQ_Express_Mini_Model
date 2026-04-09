public with sharing class ResourceRoleController {

    /**
     * Creates a new Resource Role.
     */
    @AuraEnabled
    public static Id createRole(String name, Decimal baseRate, Decimal cost, String billingUnit, 
                                 String city, String state, String country) {
        try {
            ResourceRoleService service = new ResourceRoleService();
            return service.createRole(name, baseRate, cost, billingUnit, city, state, country);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Entry point for LWC to update an existing Resource Role.
     */
    @AuraEnabled
    public static void updateRole(Id roleId, String name, Decimal baseRate, Decimal cost, String billingUnit, 
                                  String city, String state, String country) {
        try {
            ResourceRoleService service = new ResourceRoleService();
            service.updateRole(roleId, name, baseRate, cost, billingUnit, city, state, country);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Gets all active resource roles.
     */
    @AuraEnabled(cacheable=true)
    public static List<Resource_Role__c> getActiveRoles() {
        try {
            ResourceRoleService service = new ResourceRoleService();
            return service.getActiveRoles();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Gets all resource roles.
     */
    @AuraEnabled(cacheable=true)
    public static List<Resource_Role__c> getAllRoles() {
        try {
            ResourceRoleService service = new ResourceRoleService();
            return service.getAllRoles();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Deletes a resource role.
     */
    @AuraEnabled
    public static void deleteRole(Id roleId) {
        try {
            ResourceRoleService service = new ResourceRoleService();
            service.deleteRole(roleId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    /**
     * Deletes multiple resource roles by ID.
     */
    @AuraEnabled
    public static void deleteResourceRoles(List<Id> roleIds) {
        try {
            ResourceRoleService service = new ResourceRoleService();
            service.deleteResourceRoles(roleIds);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}

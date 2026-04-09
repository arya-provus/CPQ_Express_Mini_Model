public with sharing class ResourceRoleService {
    private static ResourceRoleDAO dao = new ResourceRoleDAO();

    /**
     * Creates a new Resource Role.
     * @param name Role name.
     * @param baseRate The base rate.
     * @param cost The cost.
     * @param billingUnit The billing unit.
     * @param city The city.
     * @param state The state.
     * @param country The country.
     * @return The Id of the new record.
     */
    public Id createRole(String name, Decimal baseRate, Decimal cost, String billingUnit, 
                          String city, String state, String country) {
        if (String.isBlank(name)) {
            throw new IllegalArgumentException('Resource Role name is required.');
        }
        if (baseRate == null || baseRate < 0) {
            throw new IllegalArgumentException('A valid positive base rate is required.');
        }

        Resource_Role__c role = new Resource_Role__c(
            Name = name,
            Base_Rate__c = baseRate,
            Cost__c = cost,
            Billing_Unit__c = billingUnit,
            City__c = city,
            State__c = state,
            Country__c = country,
            IsActive__c = true
        );

        Database.SaveResult result = dao.insertRole(role);
        if (result.isSuccess()) {
            return result.getId();
        } else {
            throw new AuraHandledException('Error creating resource role: ' + getErrors(result));
        }
    }

    /**
     * Updates an existing Resource Role.
     */
    public void updateRole(Id roleId, String name, Decimal baseRate, Decimal cost, String billingUnit, 
                           String city, String state, String country) {
        if (roleId == null) {
            throw new IllegalArgumentException('Role Id is required for updates.');
        }

        Resource_Role__c role = new Resource_Role__c(
            Id = roleId,
            Name = name,
            Base_Rate__c = baseRate,
            Cost__c = cost,
            Billing_Unit__c = billingUnit,
            City__c = city,
            State__c = state,
            Country__c = country
        );

        Database.SaveResult result = dao.updateRole(role);
        if (!result.isSuccess()) {
            throw new AuraHandledException('Error updating resource role: ' + getErrors(result));
        }
    }

    /**
     * Fetches all active resource roles.
     * @return List of Resource_Role__c records.
     */
    public List<Resource_Role__c> getActiveRoles() {
        return dao.getActiveRoles();
    }

    /**
     * Fetches all resource roles.
     * @return List of Resource_Role__c records.
     */
    public List<Resource_Role__c> getAllRoles() {
        return dao.getAllRoles();
    }

    /**
     * Deletes a resource role.
     * @param roleId The Id to delete.
     */
    public void deleteRole(Id roleId) {
        if (roleId == null) {
            throw new IllegalArgumentException('Role Id is required.');
        }
        dao.deleteRole(roleId);
    }

    /**
     * Deletes multiple resource roles.
     */
    public void deleteResourceRoles(List<Id> roleIds) {
        dao.deleteResourceRoles(roleIds);
    }

    private String getErrors(Database.SaveResult result) {
        String errors = '';
        for (Database.Error err : result.getErrors()) {
            errors += err.getMessage() + ' ';
        }
        return errors;
    }
}

public with sharing class ResourceRoleDAO {
    
    /**
     * Queries all active Resource Roles.
     * @return List of Resource_Role__c records.
     */
    public List<Resource_Role__c> getActiveRoles() {
        return [
            SELECT Id, Name, Base_Rate__c, Cost__c, Billing_Unit__c, 
                   City__c, State__c, Country__c, IsActive__c
            FROM Resource_Role__c
            WHERE IsActive__c = true
            ORDER BY Name ASC
        ];
    }

    /**
     * Queries all Resource Roles.
     * @return List of Resource_Role__c records.
     */
    public List<Resource_Role__c> getAllRoles() {
        return [
            SELECT Id, Name, Base_Rate__c, Cost__c, Billing_Unit__c,
                   City__c, State__c, Country__c, IsActive__c
            FROM Resource_Role__c
            ORDER BY Name ASC
        ];
    }

    /**
     * Gets a single Resource Role by Id.
     * @param roleId The Resource Role Id.
     * @return The Resource_Role__c record.
     */
    public Resource_Role__c getRoleById(Id roleId) {
        return [
            SELECT Id, Name, Base_Rate__c, Category__c, IsActive__c
            FROM Resource_Role__c
            WHERE Id = :roleId
            LIMIT 1
        ];
    }

    /**
     * Inserts a Resource_Role__c record.
     * @param role The Resource_Role__c record.
     * @return Database.SaveResult.
     */
    public Database.SaveResult insertRole(Resource_Role__c role) {
        return Database.insert(role, true);
    }

    /**
     * Updates a Resource_Role__c record.
     * @param role The Resource_Role__c record.
     * @return Database.SaveResult.
     */
    public Database.SaveResult updateRole(Resource_Role__c role) {
        return Database.update(role, true);
    }

    /**
     * Deletes a Resource_Role__c record.
     * @param roleId The Id of the record to delete.
     * @return Database.DeleteResult.
     */
    public Database.DeleteResult deleteRole(Id roleId) {
        Resource_Role__c role = new Resource_Role__c(Id = roleId);
        return Database.delete(role, true);
    }

    /**
     * Deletes multiple Resource Role records.
     * @param roleIds List of Role IDs.
     */
    public void deleteResourceRoles(List<Id> roleIds) {
        if (roleIds != null && !roleIds.isEmpty()) {
            delete [SELECT Id FROM Resource_Role__c WHERE Id IN :roleIds];
        }
    }
}

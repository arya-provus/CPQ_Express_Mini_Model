public with sharing class TeamManagerController {
    
    @AuraEnabled(cacheable=true)
    public static List<UserWrapper> getTeamMembers() {
        List<UserWrapper> results = new List<UserWrapper>();
        
        List<User> users = [SELECT Id, FirstName, LastName, Name, Email, Profile.Name, IsActive, LastLoginDate 
                            FROM User 
                            WHERE Profile.Name IN ('System Administrator', 'Admin', 'Manager', 'User', 'Standard User')
                            AND UserType = 'Standard'
                            ORDER BY Name ASC];
                            
        for(User u : users) {
            String initials = '';
            if(u.FirstName != null && u.FirstName.length() > 0) initials += u.FirstName.substring(0,1);
            if(u.LastName != null && u.LastName.length() > 0) initials += u.LastName.substring(0,1);
            if(initials == '') initials = u.Name != null ? u.Name.substring(0,1) : 'U';
            
            results.add(new UserWrapper(u, initials.toUpperCase()));
        }
        
        return results;
    }
    
    @AuraEnabled(cacheable=true)
    public static Boolean canManageUsers() {
        // Query the current user's profile
        Id profId = UserInfo.getProfileId();
        List<Profile> profs = [SELECT Name FROM Profile WHERE Id = :profId LIMIT 1];
        if(!profs.isEmpty()) {
            String pName = profs[0].Name;
            return (pName == 'System Administrator' || pName == 'Admin');
        }
        return false;
    }
    
    @AuraEnabled
    public static void createTeamMember(String firstName, String lastName, String email, String username, String roleName) {
        List<Profile> profs = [SELECT Id, Name FROM Profile WHERE Name = :roleName LIMIT 1];
        if(profs.isEmpty()) {
            throw new AuraHandledException('Invalid role selected: ' + roleName);
        }
        
        String tempAlias = (firstName != null ? firstName.substring(0,1) : '') + (lastName != null && lastName.length() > 4 ? lastName.substring(0,4) : (lastName != null ? lastName : 'usr'));
        if(tempAlias.length() > 8) {
            tempAlias = tempAlias.substring(0,8);
        }

        User newUser = new User(
            FirstName = firstName,
            LastName = lastName,
            Email = email,
            Username = username,
            Alias = tempAlias,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profs[0].Id,
            IsActive = true
        );
        
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.EmailHeader.triggerUserEmail = true;
        newUser.setOptions(dml);
        
        try {
            insert newUser;
            
            // Fire future method to prevent Mixed DML Exceptions and avoid synchronous setup clashes
            if(roleName == 'Admin' || roleName == 'Manager' || roleName == 'User') {
                assignPermissionSet(newUser.Id, roleName);
            }
        } catch(Exception e) {
            throw new AuraHandledException('Error creating user: ' + e.getMessage());
        }
    }
    
    @future
    private static void assignPermissionSet(Id userId, String roleName) {
        String psName = roleName + '_PS'; 
        List<PermissionSet> psList = [SELECT Id FROM PermissionSet WHERE Name = :psName LIMIT 1];
        if(!psList.isEmpty()) {
            PermissionSetAssignment psa = new PermissionSetAssignment(
                AssigneeId = userId,
                PermissionSetId = psList[0].Id
            );
            insert psa;
        }
    }
    
    @AuraEnabled
    public static void deactivateUser(Id userId) {
        try {
            User u = new User(Id = userId, IsActive = false);
            update u;
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public class UserWrapper {
        @AuraEnabled public String id {get; set;}
        @AuraEnabled public String name {get; set;}
        @AuraEnabled public String firstName {get; set;}
        @AuraEnabled public String lastName {get; set;}
        @AuraEnabled public String initials {get; set;}
        @AuraEnabled public String email {get; set;}
        @AuraEnabled public String role {get; set;}
        @AuraEnabled public Boolean isActive {get; set;}
        @AuraEnabled public DateTime lastLogin {get; set;}
        
        public UserWrapper(User u, String initials) {
            this.id = u.Id;
            this.name = u.Name;
            this.firstName = u.FirstName;
            this.lastName = u.LastName;
            this.initials = initials;
            this.email = u.Email;
            this.role = u.Profile.Name;
            this.isActive = u.IsActive;
            this.lastLogin = u.LastLoginDate;
        }
    }
}
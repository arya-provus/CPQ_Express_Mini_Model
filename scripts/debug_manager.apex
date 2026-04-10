String userId = '00571000007tEJGAA2';
User u = [SELECT Id, Profile.Name FROM User WHERE Id = :userId LIMIT 1];
System.debug('Profile Name: ' + u.Profile.Name);
Boolean canManage = (u.Profile.Name == 'System Administrator' || u.Profile.Name == 'Admin');
System.debug('canManage result: ' + canManage);

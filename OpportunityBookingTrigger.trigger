trigger OpportunityBookingTrigger on Opportunity (before update) {
    Set<Id> unitIds = new Set<Id>();
    
    // Collect all unit IDs
    for (Opportunity opp : Trigger.new) {
        if (opp.Unit_Number__c != null) {
            unitIds.add(opp.Unit_Number__c);
        }
    }
    
    // Query all related units
    Map<Id, Unit__c> unitsMap = new Map<Id, Unit__c>([
        SELECT Id, Unit_Status__c, Blocked_By__c, Blocking_Expiry__c 
        FROM Unit__c 
        WHERE Id IN :unitIds
    ]);
    
    for (Opportunity opp : Trigger.new) {
        Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
        
        // Check if stage is being changed and unit is assigned
        if (opp.StageName != oldOpp.StageName && 
            opp.Unit_Number__c != null) {
            
            Unit__c unit = unitsMap.get(opp.Unit_Number__c);
            
            if (unit != null) {
                // If unit is not Available and this opportunity isn't the one that blocked it
                if (unit.Unit_Status__c != 'Available' && 
                    (unit.Blocked_By__c != opp.Id || unit.Blocked_By__c == null)) {
                    opp.StageName.addError('Cannot change opportunity stage while the unit is ' 
                        + unit.Unit_Status__c + '. Please wait until the unit becomes Available.');
                    return;
                }
                
                // If this is a new booking and unit is available
                if (opp.StageName == 'Booked' && unit.Unit_Status__c == 'Available') {
                    unit.Unit_Status__c = 'Blocked';
                    unit.Blocked_By__c = opp.Id;
                    unit.Blocking_Expiry__c = System.now().addMinutes(30);
                    update unit;
                    
                    // Schedule the timeout Exactly After 30 Minutes
                    BookingTimeoutManager.scheduleUnitTimeout(unit.Id);
                }
            }
        }
    }
}

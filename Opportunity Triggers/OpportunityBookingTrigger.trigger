trigger OpportunityBookingTrigger on Opportunity (before insert, before update) {
    Set<Id> unitIds = new Set<Id>();
    List<Unit__c> unitsToUpdate = new List<Unit__c>();
    Set<Id> unitsToSchedule = new Set<Id>();
    
    // Collect all unit IDs
    for (Opportunity opp : Trigger.new) {
        if (opp.Unit_Number__c != null) {
            unitIds.add(opp.Unit_Number__c);
        }
    }
    
    if (unitIds.isEmpty()) return;
    
    // Query all units once
    Map<Id, Unit__c> unitsMap = new Map<Id, Unit__c>([
        SELECT Id, Unit_Status__c 
        FROM Unit__c 
        WHERE Id IN :unitIds
    ]);
    
    for (Opportunity opp : Trigger.new) {
        Opportunity oldOpp = Trigger.oldMap != null ? Trigger.oldMap.get(opp.Id) : null;
        
        if (opp.Unit_Number__c != null) {
            Unit__c unit = unitsMap.get(opp.Unit_Number__c);
            
            if (unit != null && unit.Unit_Status__c == 'Sold') {
                opp.addError('This unit has already been sold.');
                continue;
            }
            
            if ((Trigger.isInsert && opp.StageName == 'Booked') || 
                (Trigger.isUpdate && oldOpp != null && 
                 opp.StageName == 'Booked' && oldOpp.StageName != 'Booked')) {
                
                opp.Blocking_Expiry__c = System.now().addMinutes(30);
                unitsToSchedule.add(opp.Unit_Number__c);
                
                // Collect units to update instead of updating individually
                if (unit.Unit_Status__c != 'Blocked' && unit.Unit_Status__c != 'Sold') {
                    unit.Unit_Status__c = 'Blocked';
                    unitsToUpdate.add(unit);
                }
            }
        }
    }
    
    // Bulk update units
    if (!unitsToUpdate.isEmpty()) {
        update unitsToUpdate;
    }
    
    if (!unitsToSchedule.isEmpty()) {
        BookingTimeoutManager.scheduleUnitTimeouts(new List<Id>(unitsToSchedule));
    }
}

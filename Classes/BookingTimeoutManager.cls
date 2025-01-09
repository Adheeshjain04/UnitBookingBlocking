public class BookingTimeoutManager {
    public static void scheduleUnitTimeouts(List<Id> unitIds) {
        if (unitIds == null || unitIds.isEmpty()) {
            return;
        }
        
        // Calculate the time 30 minutes from now
        Datetime scheduleTime = System.now().addMinutes(30);
        
        // Create scheduled jobs for each unit
        for (Id unitId : unitIds) {
            
            // Create unique job name based on UnitId
            String jobName = 'UnitTimeout_' + unitId + '_' + System.now().getTime();
            
            // Create Dynamic cron expression for exact time 
            String cronExp = '' + scheduleTime.second() + ' ' 
                            + scheduleTime.minute() + ' ' 
                            + scheduleTime.hour() + ' ' 
                            + scheduleTime.day() + ' ' 
                            + scheduleTime.month() + ' ? ' 
                            + scheduleTime.year();
            
            try {
                // Schedule the job
                System.schedule(jobName, cronExp, new UnitTimeoutSchedulable(new List<Id>{unitId}));
            } catch (Exception e) {
                System.debug('Failed schedule Timeout ' + unitId + ': ' + e.getMessage());
            }
        }
    }
}

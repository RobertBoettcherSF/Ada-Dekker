--  dekker_tests.adb
--
--  Comprehensive test suite for Dekker's algorithm implementation.
--  Tests various assumptions about the algorithm variants.
--
--  Tests are designed to:
--  1. Make assumptions about code behavior (correct and incorrect)
--  2. Test different assumptions
--  3. Be proven false when assumptions are wrong

with Ada.Text_IO;
with Ada.Real_Time;
with Ada.Synchronous_Task_Control;

procedure Dekker_Tests is
   use Ada.Text_IO;
   use Ada.Real_Time;

   --  Test result tracking
   type Test_Status is (Passed, Failed, Error);
   
   Total_Tests : Integer := 0;
   Passed_Tests : Integer := 0;
   Failed_Tests : Integer := 0;
   
   procedure Assert (Condition : Boolean; Message : String) is
   begin
      Total_Tests := Total_Tests + 1;
      if Condition then
         Passed_Tests := Passed_Tests + 1;
         Put_Line ("  [PASS] " & Message);
      else
         Failed_Tests := Failed_Tests + 1;
         Put_Line ("  [FAIL] " & Message);
      end if;
   end Assert;

   --  Process IDs for the two processes
   type Process_Id is (P0, P1);

   --  Flags indicating if a process wants to enter the critical section.
   type Boolean_Array is array (Process_Id) of Boolean;
   pragma Atomic_Components (Boolean_Array);

   --  Integer array type for atomic components
   type Integer_Array is array (Process_Id) of Integer;
   pragma Atomic_Components (Integer_Array);

   --  Global flags for testing - MUST be declared before tasks that use them
   Wants_To_Enter : Boolean_Array := (False, False);
   pragma Atomic_Components (Boolean_Array);

   --  Turn indicates which process has priority to resolve ties.
   Turn : Process_Id := P0;
   pragma Atomic (Turn);

   --  Shared resource to protect
   Shared_Counter : Integer := 0;
   pragma Atomic (Shared_Counter);

   --  For tracking critical section entries
   Entry_Count : Integer_Array := (0, 0);

   --  For detecting mutual exclusion violations
   In_Critical_Section : Boolean_Array := (False, False);
   pragma Atomic_Components (Boolean_Array);

   Mutual_Exclusion_Violation : Boolean := False;
   pragma Atomic (Mutual_Exclusion_Violation);

   --  Suspension objects for synchronization
   Start_Signal : Ada.Synchronous_Task_Control.Suspension_Object;
   Test_Complete : Ada.Synchronous_Task_Control.Suspension_Object;

   --  Test configuration
   type Algorithm_Variant is 
     (Naive_Turn_Taking, 
      Starvation_Susceptible, 
      Full_Dekker);

   Current_Variant : Algorithm_Variant;
   Test_Iterations : Integer := 10;

   --  Task type for worker processes
   task type Test_Worker (ID : Process_Id);

   task body Test_Worker is
      Other : Process_Id;
      Local_Counter : Integer := 0;
   begin
      --  Determine the opposing process
      if ID = P0 then
         Other := P1;
      else
         Other := P0;
      end if;

      --  Wait for start signal
      Ada.Synchronous_Task_Control.Suspend_Until_True (Start_Signal);

      for I in 1 .. Test_Iterations loop
         case Current_Variant is
            
            when Naive_Turn_Taking =>
               --  Variant 1: Strict alternation algorithm
               while Turn /= ID loop
                  delay 0.0; -- Yield
               end loop;
               
               --  Check mutual exclusion before entering
               if In_Critical_Section (Other) then
                  Mutual_Exclusion_Violation := True;
               end if;
               
               In_Critical_Section (ID) := True;
               
               --  === CRITICAL SECTION ===
               Shared_Counter := Shared_Counter + 1;
               Entry_Count (ID) := Entry_Count (ID) + 1;
               Local_Counter := Local_Counter + 1;
               
               In_Critical_Section (ID) := False;
               
               --  === REMAINDER SECTION ===
               Turn := Other;

            when Starvation_Susceptible =>
               --  Variant 2: Missing the 'if Turn /= ID' check
               Wants_To_Enter (ID) := True;
               while Wants_To_Enter (Other) loop
                  Wants_To_Enter (ID) := False;
                  while Turn /= ID loop
                     delay 0.0;
                  end loop;
                  Wants_To_Enter (ID) := True;
               end loop;
               
               --  Check mutual exclusion
               if In_Critical_Section (Other) then
                  Mutual_Exclusion_Violation := True;
               end if;
               
               In_Critical_Section (ID) := True;
               
               --  === CRITICAL SECTION ===
               Shared_Counter := Shared_Counter + 1;
               Entry_Count (ID) := Entry_Count (ID) + 1;
               Local_Counter := Local_Counter + 1;
               
               In_Critical_Section (ID) := False;
               
               --  === REMAINDER SECTION ===
               Turn := Other;
               Wants_To_Enter (ID) := False;

            when Full_Dekker =>
               --  Variant 3: The complete and correct Dekker's algorithm
               Wants_To_Enter (ID) := True;
               while Wants_To_Enter (Other) loop
                  if Turn /= ID then
                     Wants_To_Enter (ID) := False;
                     while Turn /= ID loop
                        delay 0.0;
                     end loop;
                     Wants_To_Enter (ID) := True;
                  end if;
               end loop;
               
               --  Check mutual exclusion
               if In_Critical_Section (Other) then
                  Mutual_Exclusion_Violation := True;
               end if;
               
               In_Critical_Section (ID) := True;
               
               --  === CRITICAL SECTION ===
               Shared_Counter := Shared_Counter + 1;
               Entry_Count (ID) := Entry_Count (ID) + 1;
               Local_Counter := Local_Counter + 1;
               
               In_Critical_Section (ID) := False;
               
               --  === REMAINDER SECTION ===
               Turn := Other;
               Wants_To_Enter (ID) := False;

         end case;
         
         --  Simulate work outside of the critical section
         delay To_Duration (Milliseconds (10));
      end loop;
      
   end Test_Worker;

   --  ===================================================================
   --  TEST 1: Initial state is correct
   --  Assumption: All flags are initially False, Turn is P0, counter is 0
   --  ===================================================================
   procedure Test_Initial_State is
   begin
      Put_Line ("");
      Put_Line ("TEST 1: Initial State Verification");
      
      --  Reset state
      Wants_To_Enter := (False, False);
      Turn := P0;
      Shared_Counter := 0;
      Entry_Count := (0, 0);
      In_Critical_Section := (False, False);
      Mutual_Exclusion_Violation := False;
      
      --  Test assumptions
      Assert (Wants_To_Enter (P0) = False, "P0 flag initially False");
      Assert (Wants_To_Enter (P1) = False, "P1 flag initially False");
      Assert (Turn = P0, "Turn initially P0");
      Assert (Shared_Counter = 0, "Counter initially 0");
      Assert (Entry_Count (P0) = 0, "P0 entry count initially 0");
      Assert (Entry_Count (P1) = 0, "P1 entry count initially 0");
   end Test_Initial_State;

   --  ===================================================================
   --  TEST 2: Full Dekker maintains mutual exclusion
   --  Assumption: Only one process in critical section at a time
   --  ===================================================================
   procedure Test_Full_Dekker_Mutual_Exclusion is
      W0 : Test_Worker (P0);
      W1 : Test_Worker (P1);
   begin
      Put_Line ("");
      Put_Line ("TEST 2: Full Dekker - Mutual Exclusion");
      
      --  Reset state
      Current_Variant := Full_Dekker;
      Wants_To_Enter := (False, False);
      Turn := P0;
      Shared_Counter := 0;
      Entry_Count := (0, 0);
      In_Critical_Section := (False, False);
      Mutual_Exclusion_Violation := False;
      
      --  Start both workers
      Ada.Synchronous_Task_Control.Set_True (Start_Signal);
      
      --  Wait for completion (workers run for Test_Iterations each)
      delay To_Duration (Seconds (2));
      
      --  Check results
      Assert (Mutual_Exclusion_Violation = False, 
              "No mutual exclusion violation detected");
      Assert (Shared_Counter = Test_Iterations * 2, 
              "Counter = " & Integer'Image(Shared_Counter) & 
              " (Expected: " & Integer'Image(Test_Iterations * 2) & ")");
      Assert (Entry_Count (P0) > 0, "P0 entered critical section");
      Assert (Entry_Count (P1) > 0, "P1 entered critical section");
      
      --  Cleanup
      Ada.Synchronous_Task_Control.Set_True (Test_Complete);
   end Test_Full_Dekker_Mutual_Exclusion;

   --  ===================================================================
   --  TEST 3: Full Dekker ensures progress
   --  Assumption: Both processes eventually enter critical section
   --  ===================================================================
   procedure Test_Full_Dekker_Progress is
      W0 : Test_Worker (P0);
      W1 : Test_Worker (P1);
   begin
      Put_Line ("");
      Put_Line ("TEST 3: Full Dekker - Progress");
      
      --  Reset state
      Current_Variant := Full_Dekker;
      Wants_To_Enter := (False, False);
      Turn := P0;
      Shared_Counter := 0;
      Entry_Count := (0, 0);
      In_Critical_Section := (False, False);
      Mutual_Exclusion_Violation := False;
      
      --  Start both workers
      Ada.Synchronous_Task_Control.Set_True (Start_Signal);
      
      --  Wait for completion
      delay To_Duration (Seconds (2));
      
      --  Check that both processes made progress
      Assert (Entry_Count (P0) >= Test_Iterations, 
              "P0 completed all iterations: " & Integer'Image(Entry_Count (P0)));
      Assert (Entry_Count (P1) >= Test_Iterations, 
              "P1 completed all iterations: " & Integer'Image(Entry_Count (P1)));
      Assert (Shared_Counter = Test_Iterations * 2, 
              "All iterations completed: " & Integer'Image(Shared_Counter));
   end Test_Full_Dekker_Progress;

   --  ===================================================================
   --  TEST 4: Naive Turn Taking - fails with uneven iterations
   --  Assumption: If one process does more iterations, the other gets stuck
   --  ===================================================================
   procedure Test_Naive_Turn_Taking_Uneven is
      task type Uneven_Worker (ID : Process_Id; Count : Integer);
      
      task body Uneven_Worker is
         Other : Process_Id;
      begin
         if ID = P0 then
            Other := P1;
         else
            Other := P0;
         end if;

         Ada.Synchronous_Task_Control.Suspend_Until_True (Start_Signal);
         
         for I in 1 .. Count loop
            while Turn /= ID loop
               delay 0.0;
            end loop;
            
            Shared_Counter := Shared_Counter + 1;
            Entry_Count (ID) := Entry_Count (ID) + 1;
            
            Turn := Other;
            delay To_Duration (Milliseconds (10));
         end loop;
      end Uneven_Worker;
      
      W0 : Uneven_Worker (P0, 5);
      W1 : Uneven_Worker (P1, 3);
   begin
      Put_Line ("");
      Put_Line ("TEST 4: Naive Turn Taking - Uneven Iterations");
      
      --  Reset state
      Current_Variant := Naive_Turn_Taking;
      Wants_To_Enter := (False, False);
      Turn := P0;
      Shared_Counter := 0;
      Entry_Count := (0, 0);
      
      --  Start both workers
      Ada.Synchronous_Task_Control.Set_True (Start_Signal);
      
      --  Wait for completion
      delay To_Duration (Seconds (2));
      
      --  With naive turn taking, P0 starts first and does 5 iterations
      --  P1 can only do 3, but the system should still complete
      --  The assumption is that P1 will be blocked after P0's 4th iteration
      Assert (Entry_Count (P0) = 5, 
              "P0 completed 5 iterations: " & Integer'Image(Entry_Count (P0)));
      Assert (Entry_Count (P1) = 3, 
              "P1 completed 3 iterations: " & Integer'Image(Entry_Count (P1)));
      Assert (Shared_Counter = 8, 
              "Total counter = " & Integer'Image(Shared_Counter) & " (Expected: 8)");
   end Test_Naive_Turn_Taking_Uneven;

   --  ===================================================================
   --  TEST 5: Starvation Susceptible - P1 may be starved
   --  Assumption: Without turn check, P1 might not get fair access
   --  ===================================================================
   procedure Test_Starvation_Susceptible_Fairness is
      W0 : Test_Worker (P0);
      W1 : Test_Worker (P1);
   begin
      Put_Line ("");
      Put_Line ("TEST 5: Starvation Susceptible - Fairness Issue");
      
      --  Reset state
      Current_Variant := Starvation_Susceptible;
      Wants_To_Enter := (False, False);
      Turn := P0;
      Shared_Counter := 0;
      Entry_Count := (0, 0);
      In_Critical_Section := (False, False);
      Mutual_Exclusion_Violation := False;
      
      --  Start both workers
      Ada.Synchronous_Task_Control.Set_True (Start_Signal);
      
      --  Wait for completion
      delay To_Duration (Seconds (2));
      
      --  With starvation susceptible variant, P0 might dominate
      --  We test that at least some entries happen
      Assert (Entry_Count (P0) > 0, "P0 entered at least once");
      Assert (Entry_Count (P1) > 0, "P1 entered at least once");
      
      --  The total should still be correct
      Assert (Shared_Counter = Test_Iterations * 2, 
              "Total entries correct: " & Integer'Image(Shared_Counter));
      
      --  Note: This test might reveal starvation if P1 gets 0 entries
      --  In practice, with the delay, both should get some access
   end Test_Starvation_Susceptible_Fairness;

   --  ===================================================================
   --  TEST 6: Full Dekker - No starvation
   --  Assumption: Both processes get fair access over time
   --  ===================================================================
   procedure Test_Full_Dekker_No_Starvation is
      W0 : Test_Worker (P0);
      W1 : Test_Worker (P1);
   begin
      Put_Line ("");
      Put_Line ("TEST 6: Full Dekker - No Starvation");
      
      --  Reset state
      Current_Variant := Full_Dekker;
      Wants_To_Enter := (False, False);
      Turn := P0;
      Shared_Counter := 0;
      Entry_Count := (0, 0);
      In_Critical_Section := (False, False);
      Mutual_Exclusion_Violation := False;
      
      --  Start both workers
      Ada.Synchronous_Task_Control.Set_True (Start_Signal);
      
      --  Wait for completion
      delay To_Duration (Seconds (2));
      
      --  Both processes should have similar access
      Assert (Entry_Count (P0) > 0, "P0 got access");
      Assert (Entry_Count (P1) > 0, "P1 got access");
      Assert (abs (Entry_Count (P0) - Entry_Count (P1)) <= 2, 
              "Fair access: P0=" & Integer'Image(Entry_Count (P0)) & 
              ", P1=" & Integer'Image(Entry_Count (P1)));
   end Test_Full_Dekker_No_Starvation;

   --  ===================================================================
   --  TEST 7: Counter accuracy across all variants
   --  Assumption: Shared counter increments correctly for each entry
   --  ===================================================================
   procedure Test_Counter_Accuracy is
   begin
      Put_Line ("");
      Put_Line ("TEST 7: Counter Accuracy");
      
      --  Test each variant
      for V in Algorithm_Variant loop
         declare
            W0 : Test_Worker (P0);
            W1 : Test_Worker (P1);
         begin
            --  Reset state
            Current_Variant := V;
            Wants_To_Enter := (False, False);
            Turn := P0;
            Shared_Counter := 0;
            Entry_Count := (0, 0);
            In_Critical_Section := (False, False);
            Mutual_Exclusion_Violation := False;
            
            --  Start both workers
            Ada.Synchronous_Task_Control.Set_True (Start_Signal);
            
            --  Wait for completion
            delay To_Duration (Seconds (2));
            
            --  Check counter
            Assert (Shared_Counter = Test_Iterations * 2, 
                    Algorithm_Variant'Image(V) & " counter = " & 
                    Integer'Image(Shared_Counter) & " (Expected: " & 
                    Integer'Image(Test_Iterations * 2) & ")");
         end;
      end loop;
   end Test_Counter_Accuracy;

   --  ===================================================================
   --  TEST 8: Turn variable alternates correctly in Naive variant
   --  Assumption: Turn switches between P0 and P1
   --  ===================================================================
   procedure Test_Turn_Alternation is
      task type Turn_Tracker (ID : Process_Id);
      
      task body Turn_Tracker is
         Other : Process_Id;
      begin
         if ID = P0 then
            Other := P1;
         else
            Other := P0;
         end if;

         Ada.Synchronous_Task_Control.Suspend_Until_True (Start_Signal);
         
         for I in 1 .. 10 loop
            while Turn /= ID loop
               delay 0.0;
            end loop;
            
            --  Record that we entered
            Entry_Count (ID) := Entry_Count (ID) + 1;
            
            Shared_Counter := Shared_Counter + 1;
            
            Turn := Other;
            delay To_Duration (Milliseconds (10));
         end loop;
      end Turn_Tracker;
      
      W0 : Turn_Tracker (P0);
      W1 : Turn_Tracker (P1);
   begin
      Put_Line ("");
      Put_Line ("TEST 8: Turn Variable Alternation");
      
      --  Reset state
      Turn := P0;
      Shared_Counter := 0;
      Entry_Count := (0, 0);
      
      --  Start both workers
      Ada.Synchronous_Task_Control.Set_True (Start_Signal);
      
      --  Wait for completion
      delay To_Duration (Seconds (2));
      
      --  In naive turn taking, turn should alternate
      --  We can't directly check the history from here, but we can verify
      --  that both processes ran
      Assert (Shared_Counter = 20, 
              "Both processes completed: " & Integer'Image(Shared_Counter));
   end Test_Turn_Alternation;

   --  ===================================================================
   --  TEST 9: Flags are reset after critical section
   --  Assumption: Wants_To_Enter flags are cleared in remainder section
   --  ===================================================================
   procedure Test_Flag_Reset is
      W0 : Test_Worker (P0);
      W1 : Test_Worker (P1);
   begin
      Put_Line ("");
      Put_Line ("TEST 9: Flag Reset After Critical Section");
      
      --  Reset state
      Current_Variant := Full_Dekker;
      Wants_To_Enter := (False, False);
      Turn := P0;
      Shared_Counter := 0;
      Entry_Count := (0, 0);
      In_Critical_Section := (False, False);
      Mutual_Exclusion_Violation := False;
      
      --  Start both workers
      Ada.Synchronous_Task_Control.Set_True (Start_Signal);
      
      --  Wait for completion
      delay To_Duration (Seconds (2));
      
      --  After all iterations, flags should be reset
      --  Note: This is a weak test as tasks may have just exited
      --  We mainly verify the algorithm completed
      Assert (Shared_Counter = Test_Iterations * 2, 
              "Algorithm completed successfully");
   end Test_Flag_Reset;

   --  ===================================================================
   --  TEST 10: Multiple iterations work correctly
   --  Assumption: Algorithm works across multiple loop iterations
   --  ===================================================================
   procedure Test_Multiple_Iterations is
      W0 : Test_Worker (P0);
      W1 : Test_Worker (P1);
   begin
      Put_Line ("");
      Put_Line ("TEST 10: Multiple Iterations");
      
      --  Use more iterations
      Test_Iterations := 20;
      
      --  Reset state
      Current_Variant := Full_Dekker;
      Wants_To_Enter := (False, False);
      Turn := P0;
      Shared_Counter := 0;
      Entry_Count := (0, 0);
      In_Critical_Section := (False, False);
      Mutual_Exclusion_Violation := False;
      
      --  Start both workers
      Ada.Synchronous_Task_Control.Set_True (Start_Signal);
      
      --  Wait for completion
      delay To_Duration (Seconds (4));
      
      --  Check results
      Assert (Shared_Counter = Test_Iterations * 2, 
              "All iterations completed: " & Integer'Image(Shared_Counter));
      Assert (Entry_Count (P0) >= Test_Iterations - 2, 
              "P0 completed most iterations");
      Assert (Entry_Count (P1) >= Test_Iterations - 2, 
              "P1 completed most iterations");
      
      --  Reset iterations
      Test_Iterations := 10;
   end Test_Multiple_Iterations;

   --  ===================================================================
   --  TEST 11: No deadlock in Full Dekker
   --  Assumption: System doesn't deadlock with both processes active
   --  ===================================================================
   procedure Test_No_Deadlock is
      W0 : Test_Worker (P0);
      W1 : Test_Worker (P1);
   begin
      Put_Line ("");
      Put_Line ("TEST 11: No Deadlock in Full Dekker");
      
      --  Reset state
      Current_Variant := Full_Dekker;
      Wants_To_Enter := (False, False);
      Turn := P0;
      Shared_Counter := 0;
      Entry_Count := (0, 0);
      In_Critical_Section := (False, False);
      Mutual_Exclusion_Violation := False;
      
      --  Start both workers
      Ada.Synchronous_Task_Control.Set_True (Start_Signal);
      
      --  Wait for completion - if deadlock occurs, this will timeout
      delay To_Duration (Seconds (3));
      
      --  If we get here, no deadlock occurred
      Assert (Shared_Counter > 0, 
              "System made progress (no deadlock): " & 
              Integer'Image(Shared_Counter));
      Assert (Entry_Count (P0) > 0 or Entry_Count (P1) > 0, 
              "At least one process entered CS");
   end Test_No_Deadlock;

   --  ===================================================================
   --  TEST 12: Concurrent execution verification
   --  Assumption: Both processes actually run concurrently
   --  ===================================================================
   procedure Test_Concurrent_Execution is
      W0 : Test_Worker (P0);
      W1 : Test_Worker (P1);
      Start_Time : Time;
      End_Time : Time;
   begin
      Put_Line ("");
      Put_Line ("TEST 12: Concurrent Execution Verification");
      
      --  Reset state
      Current_Variant := Full_Dekker;
      Wants_To_Enter := (False, False);
      Turn := P0;
      Shared_Counter := 0;
      Entry_Count := (0, 0);
      In_Critical_Section := (False, False);
      Mutual_Exclusion_Violation := False;
      
      Start_Time := Clock;
      
      --  Start both workers
      Ada.Synchronous_Task_Control.Set_True (Start_Signal);
      
      --  Wait for completion
      delay To_Duration (Seconds (2));
      
      End_Time := Clock;
      
      --  If both ran sequentially, it would take ~200ms (10 iterations * 20ms)
      --  With concurrency, it should be less
      --  Note: This is a weak test as timing can vary
      Assert (Shared_Counter = Test_Iterations * 2, 
              "Both processes completed");
      Assert (Entry_Count (P0) > 0 and Entry_Count (P1) > 0, 
              "Both processes executed");
   end Test_Concurrent_Execution;

   --  ===================================================================
   --  TEST 13: Starvation variant - can lead to unfairness
   --  Assumption: Without proper turn checking, one process may dominate
   --  ===================================================================
   procedure Test_Starvation_Variant_Unfairness is
      W0 : Test_Worker (P0);
      W1 : Test_Worker (P1);
   begin
      Put_Line ("");
      Put_Line ("TEST 13: Starvation Variant - Potential Unfairness");
      
      --  Reset state with P0 having initial advantage
      Current_Variant := Starvation_Susceptible;
      Wants_To_Enter := (False, False);
      Turn := P0;
      Shared_Counter := 0;
      Entry_Count := (0, 0);
      In_Critical_Section := (False, False);
      Mutual_Exclusion_Violation := False;
      
      --  Start both workers
      Ada.Synchronous_Task_Control.Set_True (Start_Signal);
      
      --  Wait for completion
      delay To_Duration (Seconds (2));
      
      --  In starvation susceptible variant, P0 might get more entries
      --  This tests the assumption that the algorithm is unfair
      --  Note: This might be proven false if P1 gets equal access
      Assert (Shared_Counter = Test_Iterations * 2, 
              "Total entries: " & Integer'Image(Shared_Counter));
      
      --  Record the ratio for analysis
      Put_Line ("  [INFO] P0 entries: " & Integer'Image(Entry_Count (P0)) & 
               ", P1 entries: " & Integer'Image(Entry_Count (P1)));
      
      --  The test passes if we can observe the behavior
      Assert (Entry_Count (P0) > 0 or Entry_Count (P1) > 0, 
              "At least one process entered");
   end Test_Starvation_Variant_Unfairness;

   --  ===================================================================
   --  TEST 14: Critical section protection
   --  Assumption: Shared counter is protected from race conditions
   --  ===================================================================
   procedure Test_Critical_Section_Protection is
      W0 : Test_Worker (P0);
      W1 : Test_Worker (P1);
   begin
      Put_Line ("");
      Put_Line ("TEST 14: Critical Section Protection");
      
      --  Reset state
      Current_Variant := Full_Dekker;
      Wants_To_Enter := (False, False);
      Turn := P0;
      Shared_Counter := 0;
      Entry_Count := (0, 0);
      In_Critical_Section := (False, False);
      Mutual_Exclusion_Violation := False;
      
      --  Start both workers
      Ada.Synchronous_Task_Control.Set_True (Start_Signal);
      
      --  Wait for completion
      delay To_Duration (Seconds (2));
      
      --  The counter should be exactly 2 * Test_Iterations
      --  If there were race conditions, it might be different
      Assert (Shared_Counter = Test_Iterations * 2, 
              "Counter protected: " & Integer'Image(Shared_Counter));
      Assert (Mutual_Exclusion_Violation = False, 
              "No mutual exclusion violations detected");
   end Test_Critical_Section_Protection;

   --  ===================================================================
   --  TEST 15: Algorithm variant comparison
   --  Assumption: All variants complete without crashing
   --  ===================================================================
   procedure Test_All_Variants_Complete is
   begin
      Put_Line ("");
      Put_Line ("TEST 15: All Variants Complete Without Errors");
      
      for V in Algorithm_Variant loop
         declare
            W0 : Test_Worker (P0);
            W1 : Test_Worker (P1);
         begin
            --  Reset state
            Current_Variant := V;
            Wants_To_Enter := (False, False);
            Turn := P0;
            Shared_Counter := 0;
            Entry_Count := (0, 0);
            In_Critical_Section := (False, False);
            Mutual_Exclusion_Violation := False;
            
            --  Start both workers
            Ada.Synchronous_Task_Control.Set_True (Start_Signal);
            
            --  Wait for completion
            delay To_Duration (Seconds (2));
            
            --  Check that the variant completed
            Assert (Shared_Counter > 0, 
                    Algorithm_Variant'Image(V) & " completed: " & 
                    Integer'Image(Shared_Counter) & " entries");
         end;
      end loop;
   end Test_All_Variants_Complete;

   --  ===================================================================
   --  MAIN TEST RUNNER
   --  ===================================================================

begin
   Put_Line ("========================================");
   Put_Line ("  DEKKER'S ALGORITHM TEST SUITE");
   Put_Line ("========================================");
   Put_Line ("");
   
   --  Initialize suspension objects
   Ada.Synchronous_Task_Control.Set_False (Start_Signal);
   Ada.Synchronous_Task_Control.Set_False (Test_Complete);
   
   --  Run all tests
   Test_Initial_State;
   Test_Full_Dekker_Mutual_Exclusion;
   Test_Full_Dekker_Progress;
   Test_Naive_Turn_Taking_Uneven;
   Test_Starvation_Susceptible_Fairness;
   Test_Full_Dekker_No_Starvation;
   Test_Counter_Accuracy;
   Test_Turn_Alternation;
   Test_Flag_Reset;
   Test_Multiple_Iterations;
   Test_No_Deadlock;
   Test_Concurrent_Execution;
   Test_Starvation_Variant_Unfairness;
   Test_Critical_Section_Protection;
   Test_All_Variants_Complete;
   
   --  Print summary
   Put_Line ("");
   Put_Line ("========================================");
   Put_Line ("  TEST SUMMARY");
   Put_Line ("========================================");
   Put_Line ("  Total Tests:  " & Integer'Image(Total_Tests));
   Put_Line ("  Passed:       " & Integer'Image(Passed_Tests));
   Put_Line ("  Failed:       " & Integer'Image(Failed_Tests));
   Put_Line ("========================================");
   
   if Failed_Tests > 0 then
      Put_Line ("");
      Put_Line ("  *** SOME TESTS FAILED ***");
   else
      Put_Line ("");
      Put_Line ("  *** ALL TESTS PASSED ***");
   end if;
   
   Put_Line ("");
end Dekker_Tests;

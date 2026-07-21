--  dekker_tests.adb
--
--  Comprehensive test suite for Dekker's algorithm implementation.
--

with Ada.Text_IO;
with Ada.Real_Time;
with Ada.Synchronous_Task_Control;

procedure Dekker_Tests is
   use Ada.Text_IO;
   use Ada.Real_Time;

   --  Test result tracking
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

   --  Global flags for testing
   Wants_To_Enter : Boolean_Array := (False, False);

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

   Mutual_Exclusion_Violation : Boolean := False;
   pragma Atomic (Mutual_Exclusion_Violation);

   --  Test configuration
   type Algorithm_Variant is 
     (Naive_Turn_Taking, 
      Starvation_Susceptible, 
      Full_Dekker);

   Current_Variant : Algorithm_Variant;
   Test_Iterations : constant Integer := 10;

   --  Task type for worker processes
   task type Test_Worker (ID : Process_Id);

   task body Test_Worker is
      Other : Process_Id;
   begin
      --  Determine the opposing process
      if ID = P0 then
         Other := P1;
      else
         Other := P0;
      end if;

      Put_Line ("    Worker " & Process_Id'Image(ID) & " started");

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
               
               In_Critical_Section (ID) := False;
               
               --  === REMAINDER SECTION ===
               Turn := Other;
               Wants_To_Enter (ID) := False;

         end case;
         
         --  Simulate work outside of the critical section
         delay To_Duration (Milliseconds (10));
      end loop;
      
      Put_Line ("    Worker " & Process_Id'Image(ID) & " finished");
      
   end Test_Worker;

   --  Task type for uneven worker processes (for Test 4)
   task type Uneven_Worker (ID : Process_Id; Count : Integer);

   task body Uneven_Worker is
      Other : Process_Id;
   begin
      if ID = P0 then
         Other := P1;
      else
         Other := P0;
      end if;

      Put_Line ("    UnevenWorker " & Process_Id'Image(ID) & " started with " & Integer'Image(Count) & " iterations");
      
      for I in 1 .. Count loop
         while Turn /= ID loop
            delay 0.0;
         end loop;
         
         Shared_Counter := Shared_Counter + 1;
         Entry_Count (ID) := Entry_Count (ID) + 1;
         
         Turn := Other;
         delay To_Duration (Milliseconds (10));
      end loop;
      
      Put_Line ("    UnevenWorker " & Process_Id'Image(ID) & " finished");
   end Uneven_Worker;

   --  Reset all shared state for a new test
   procedure Reset_State is
   begin
      Wants_To_Enter := (False, False);
      Turn := P0;
      Shared_Counter := 0;
      Entry_Count := (0, 0);
      In_Critical_Section := (False, False);
      Mutual_Exclusion_Violation := False;
   end Reset_State;

   --  ===================================================================
   --  TEST 1: Initial state is correct
   --  ===================================================================
   procedure Test_Initial_State is
   begin
      Put_Line ("");
      Put_Line ("TEST 1: Initial State Verification");
      
      Reset_State;
      
      Assert (Wants_To_Enter (P0) = False, "P0 flag initially False");
      Assert (Wants_To_Enter (P1) = False, "P1 flag initially False");
      Assert (Turn = P0, "Turn initially P0");
      Assert (Shared_Counter = 0, "Counter initially 0");
      Assert (Entry_Count (P0) = 0, "P0 entry count initially 0");
      Assert (Entry_Count (P1) = 0, "P1 entry count initially 0");
   end Test_Initial_State;

   --  ===================================================================
   --  TEST 2: Full Dekker maintains mutual exclusion
   --  ===================================================================
   procedure Test_Full_Dekker_Mutual_Exclusion is
      W0 : Test_Worker (P0);
      W1 : Test_Worker (P1);
   begin
      Put_Line ("");
      Put_Line ("TEST 2: Full Dekker - Mutual Exclusion");
      
      Reset_State;
      Current_Variant := Full_Dekker;
      
      --  Wait a bit for tasks to start
      delay To_Duration (Seconds (0.1));
      
      --  Wait for completion
      delay To_Duration (Seconds (3));
      
      Put_Line ("    Final: P0=" & Integer'Image(Entry_Count (P0)) & 
                ", P1=" & Integer'Image(Entry_Count (P1)) & 
                ", Counter=" & Integer'Image(Shared_Counter));
      
      Assert (Mutual_Exclusion_Violation = False, 
              "No mutual exclusion violation detected");
      Assert (Shared_Counter = Test_Iterations * 2, 
              "Counter = " & Integer'Image(Shared_Counter) & 
              " (Expected: " & Integer'Image(Test_Iterations * 2) & ")");
      Assert (Entry_Count (P0) > 0, "P0 entered critical section");
      Assert (Entry_Count (P1) > 0, "P1 entered critical section");
   end Test_Full_Dekker_Mutual_Exclusion;

   --  ===================================================================
   --  TEST 3: Full Dekker ensures progress
   --  ===================================================================
   procedure Test_Full_Dekker_Progress is
      W0 : Test_Worker (P0);
      W1 : Test_Worker (P1);
   begin
      Put_Line ("");
      Put_Line ("TEST 3: Full Dekker - Progress");
      
      Reset_State;
      Current_Variant := Full_Dekker;
      
      --  Wait a bit for tasks to start
      delay To_Duration (Seconds (0.1));
      
      --  Wait for completion
      delay To_Duration (Seconds (3));
      
      Put_Line ("    Final: P0=" & Integer'Image(Entry_Count (P0)) & 
                ", P1=" & Integer'Image(Entry_Count (P1)) & 
                ", Counter=" & Integer'Image(Shared_Counter));
      
      Assert (Entry_Count (P0) >= Test_Iterations, 
              "P0 completed all iterations: " & Integer'Image(Entry_Count (P0)));
      Assert (Entry_Count (P1) >= Test_Iterations, 
              "P1 completed all iterations: " & Integer'Image(Entry_Count (P1)));
      Assert (Shared_Counter = Test_Iterations * 2, 
              "All iterations completed: " & Integer'Image(Shared_Counter));
   end Test_Full_Dekker_Progress;

   --  ===================================================================
   --  TEST 4: Naive Turn Taking with equal iterations
   --  ===================================================================
   procedure Test_Naive_Turn_Taking_Equal is
      W0 : Uneven_Worker (P0, 3);
      W1 : Uneven_Worker (P1, 3);
   begin
      Put_Line ("");
      Put_Line ("TEST 4: Naive Turn Taking - Equal Iterations");
      
      Reset_State;
      Current_Variant := Naive_Turn_Taking;
      
      --  Wait for completion
      delay To_Duration (Seconds (2));
      
      Put_Line ("    Final: P0=" & Integer'Image(Entry_Count (P0)) & 
                ", P1=" & Integer'Image(Entry_Count (P1)) & 
                ", Counter=" & Integer'Image(Shared_Counter));
      
      Assert (Entry_Count (P0) = 3, 
              "P0 completed 3 iterations: " & Integer'Image(Entry_Count (P0)));
      Assert (Entry_Count (P1) = 3, 
              "P1 completed 3 iterations: " & Integer'Image(Entry_Count (P1)));
      Assert (Shared_Counter = 6, 
              "Total counter = " & Integer'Image(Shared_Counter) & " (Expected: 6)");
   end Test_Naive_Turn_Taking_Equal;

   --  ===================================================================
   --  TEST 5: Starvation Susceptible fairness
   --  ===================================================================
   procedure Test_Starvation_Susceptible_Fairness is
      W0 : Test_Worker (P0);
      W1 : Test_Worker (P1);
   begin
      Put_Line ("");
      Put_Line ("TEST 5: Starvation Susceptible - Fairness");
      
      Reset_State;
      Current_Variant := Starvation_Susceptible;
      
      --  Wait a bit for tasks to start
      delay To_Duration (Seconds (0.1));
      
      --  Wait for completion
      delay To_Duration (Seconds (3));
      
      Put_Line ("    Final: P0=" & Integer'Image(Entry_Count (P0)) & 
                ", P1=" & Integer'Image(Entry_Count (P1)) & 
                ", Counter=" & Integer'Image(Shared_Counter));
      
      Assert (Entry_Count (P0) > 0, "P0 entered at least once");
      Assert (Entry_Count (P1) > 0, "P1 entered at least once");
      Assert (Shared_Counter = Test_Iterations * 2, 
              "Total entries correct: " & Integer'Image(Shared_Counter));
   end Test_Starvation_Susceptible_Fairness;

   --  ===================================================================
   --  TEST 6: Full Dekker - No starvation
   --  ===================================================================
   procedure Test_Full_Dekker_No_Starvation is
      W0 : Test_Worker (P0);
      W1 : Test_Worker (P1);
   begin
      Put_Line ("");
      Put_Line ("TEST 6: Full Dekker - No Starvation");
      
      Reset_State;
      Current_Variant := Full_Dekker;
      
      --  Wait a bit for tasks to start
      delay To_Duration (Seconds (0.1));
      
      --  Wait for completion
      delay To_Duration (Seconds (3));
      
      Put_Line ("    Final: P0=" & Integer'Image(Entry_Count (P0)) & 
                ", P1=" & Integer'Image(Entry_Count (P1)) & 
                ", Counter=" & Integer'Image(Shared_Counter));
      
      Assert (Entry_Count (P0) > 0, "P0 got access");
      Assert (Entry_Count (P1) > 0, "P1 got access");
      Assert (abs (Entry_Count (P0) - Entry_Count (P1)) <= 2, 
              "Fair access: P0=" & Integer'Image(Entry_Count (P0)) & 
              ", P1=" & Integer'Image(Entry_Count (P1)));
   end Test_Full_Dekker_No_Starvation;

   --  ===================================================================
   --  TEST 7: No deadlock in Full Dekker
   --  ===================================================================
   procedure Test_No_Deadlock is
      W0 : Test_Worker (P0);
      W1 : Test_Worker (P1);
   begin
      Put_Line ("");
      Put_Line ("TEST 7: No Deadlock in Full Dekker");
      
      Reset_State;
      Current_Variant := Full_Dekker;
      
      --  Wait a bit for tasks to start
      delay To_Duration (Seconds (0.1));
      
      --  Wait for completion
      delay To_Duration (Seconds (3));
      
      Put_Line ("    Final: P0=" & Integer'Image(Entry_Count (P0)) & 
                ", P1=" & Integer'Image(Entry_Count (P1)) & 
                ", Counter=" & Integer'Image(Shared_Counter));
      
      Assert (Shared_Counter > 0, 
              "System made progress (no deadlock): " & 
              Integer'Image(Shared_Counter));
      Assert (Entry_Count (P0) > 0 or Entry_Count (P1) > 0, 
              "At least one process entered CS");
   end Test_No_Deadlock;

begin
   Put_Line ("=== Dekker's Algorithm Test Suite ===");
   Put_Line ("");
   
   --  Run all tests
   Test_Initial_State;
   Test_Full_Dekker_Mutual_Exclusion;
   Test_Full_Dekker_Progress;
   Test_Naive_Turn_Taking_Equal;
   Test_Starvation_Susceptible_Fairness;
   Test_Full_Dekker_No_Starvation;
   Test_No_Deadlock;
   
   --  Print summary
   Put_Line ("");
   Put_Line ("=== Test Summary ===");
   Put_Line ("Total Tests: " & Integer'Image(Total_Tests));
   Put_Line ("Passed: " & Integer'Image(Passed_Tests));
   Put_Line ("Failed: " & Integer'Image(Failed_Tests));
   
   if Failed_Tests = 0 then
      Put_Line ("All tests PASSED!");
   else
      Put_Line ("Some tests FAILED!");
   end if;
   
   Put_Line ("=== Test Suite Finished ===");
end Dekker_Tests;

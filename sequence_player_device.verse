sequence_player_module<public> := module:
    using { device_settings_module }
    using { /Fortnite.com/Devices }
    using { sequence_player_util_module }
    using { /Verse.org/Simulation }

    sequence_player_device<public> := class<final>(creative_device):
        @editable
        Option_Triggers<private>:sequence_option_triggers = sequence_option_triggers{}

        @editable_container:
            AllowReordering := true
        Sequence_Queue<private>:[]sequence_trigger = array{}

        OnBegin<override>()<suspends>:void =
            QueuedSequencePlayer := MakeQueuedSequencePlayer(Option_Triggers)
            QueuedSequencePlayer.Initialize()
            for (Pair : Sequence_Queue):
                QueuedSequencePlayer.Enqueue(Pair.Sequence, Pair.Trigger)

    device_settings_module<internal> := module:
        sequence_trigger<public> := struct<concrete>:
            @editable
            Sequence:cinematic_sequence_device = cinematic_sequence_device{}

            @editable
            Trigger:trigger_device = trigger_device{}

        sequence_option_triggers<public> := struct<concrete>:
            @editable
            Start:trigger_device = trigger_device{}

            @editable
            Toggle_Pause:trigger_device = trigger_device{}

            @editable
            Skip:trigger_device = trigger_device{}

            @editable
            Previous:trigger_device = trigger_device{}

            @editable
            Toggle_Loop:trigger_device = trigger_device{}

    sequence_player_util_module<internal> := module:
        MakeQueuedSequencePlayer<public><constructor>(Triggers:sequence_option_triggers)<transacts> := queued_sequence_player:
            StartTrigger := Triggers.Start
            SkipTrigger := Triggers.Skip
            PreviousTrigger := Triggers.Previous
            TogglePauseTrigger := Triggers.Toggle_Pause
            ToggleLoopTrigger := Triggers.Toggle_Loop

        sequence_player_interface<public> := interface<internal>:
            Initialize<public>():void

            AwaitStartTriggered<internal>()<suspends>:void

            AwaitTogglePauseTriggered<internal>()<suspends>:void

            AwaitToggleLoopTriggered<internal>()<suspends>:void

            (:cinematic_sequence_device).AwaitStopped<internal>()<suspends>:void

        queueable_sequence_player<public> := interface<internal>:
            Enqueue<public>(:cinematic_sequence_device, :trigger_device):void

            AwaitSkipTriggered<internal>()<suspends>:void

            AwaitPreviousTriggered<internal>()<suspends>:void

        MakeSequenceNode<internal><constructor>(Sequence:cinematic_sequence_device, Next:?sequence_node, Prev:?sequence_node)<transacts> := sequence_node:
            Sequence := Sequence
            Next := Next
            Prev := Prev

        MakeTriggerDeviceWrapper<internal><constructor>(Trigger:trigger_device)<transacts> := trigger_device_wrapper:
            Trigger := Trigger

        queued_sequence_player<public> := class<internal><final><unique>(sequence_player, queueable_sequence_player):
            StartTrigger:trigger_device
            SkipTrigger:trigger_device
            PreviousTrigger:trigger_device

            SequenceQueue<private>:sequence_queue = sequence_queue{}

            var Initialized<private>:logic = false
            var PlayNextSequence<protected>:logic = true

            Initialize<override>():void =
                (super:)Initialize()
                spawn{AwaitStartTriggered()}
                spawn{AwaitSkipTriggered()}
                spawn{AwaitPreviousTriggered()}
                set Initialized = true

            Enqueue<override>(Sequence:cinematic_sequence_device, Trigger:trigger_device):void =
                if (Initialized?):
                    TriggerWrapper := MakeTriggerDeviceWrapper(Trigger)
                    SequenceQueue.Push(TriggerWrapper, Sequence)
                    spawn{TriggerWrapper.AwaitTriggered()}
                    spawn{Sequence.AwaitStopped()}

            AwaitStartTriggered<override><final>()<suspends>:void =
                loop:
                    StartTrigger.TriggeredEvent.Await()
                    if (CurrentSequence := MaybeCurrentSequence?):
                        set PlayNextSequence = false
                        CurrentSequence.Stop()
                        Sleep(0.1)
                        set PlayNextSequence = true
                    SequenceQueue.ToBegin()
                    if (Sequence := SequenceQueue.Get[]):
                        Sequence.Play()
                        set MaybeCurrentSequence = option{Sequence}

            AwaitSkipTriggered<override><final>()<suspends>:void =
                loop:
                    SkipTrigger.TriggeredEvent.Await()
                    if (CurrentSequence := MaybeCurrentSequence?):
                        set IsLooping = false
                        CurrentSequence.Stop()

            AwaitPreviousTriggered<override><final>()<suspends>:void =
                loop:
                    PreviousTrigger.TriggeredEvent.Await()
                    if (CurrentSequence := MaybeCurrentSequence?):
                        set PlayNextSequence = false
                        CurrentSequence.Stop()
                        Sleep(0.1)
                        set PlayNextSequence = true
                        if (SequenceQueue.Previous[], PreviousSequence := SequenceQueue.Get[]):
                            set MaybeCurrentSequence = option{PreviousSequence}
                            PreviousSequence.Play()

            (Sequence:cinematic_sequence_device).AwaitStopped<override><final>()<suspends>:void =
                loop:
                    Sequence.StoppedEvent.Await()
                    if (IsLooping?):
                        Sequence.Play()
                    else if:
                        PlayNextSequence?
                        SequenceQueue.Next[]
                        NextSequence := SequenceQueue.Get[]
                    then:
                        set MaybeCurrentSequence = option{NextSequence}
                        NextSequence.Play()

            (TriggerWrapper:trigger_device_wrapper).AwaitTriggered<private>()<suspends>:void =
                TriggeredEvent := TriggerWrapper.TriggeredEvent()
                loop:
                    TriggeredEvent.Await()
                    if (CurrentSequence := MaybeCurrentSequence?):
                        set PlayNextSequence = false
                        CurrentSequence.Stop()
                        Sleep(0.1)
                        set PlayNextSequence = true
                    if (SequenceQueue.Set[TriggerWrapper], Sequence := SequenceQueue.Get[]):
                        set MaybeCurrentSequence = option{Sequence}
                        Sequence.Play()

        sequence_player<internal> := class<abstract>(sequence_player_interface):
            TogglePauseTrigger:trigger_device
            ToggleLoopTrigger:trigger_device

            var IsLooping<protected>:logic = false
            var MaybeCurrentSequence<protected>:?cinematic_sequence_device = false

            Initialize<override>():void =
                spawn{AwaitTogglePauseTriggered()}
                spawn{AwaitToggleLoopTriggered()}
            
            AwaitTogglePauseTriggered<override><final>()<suspends>:void =
                loop:
                    TogglePauseTrigger.TriggeredEvent.Await()
                    if (CurrentSequence := MaybeCurrentSequence?):
                        CurrentSequence.TogglePause()

            AwaitToggleLoopTriggered<override><final>()<suspends>:void =
                loop:
                    ToggleLoopTrigger.TriggeredEvent.Await()
                    set IsLooping = if (IsLooping?) then false else true
        
        sequence_queue<internal> := class<final>:
            TriggerSequenceLookup<private>:trigger_sequence_lookup = trigger_sequence_lookup{}

            var Head<private>:?sequence_node = false
            var Tail<private>:?sequence_node = false
            var Current<private>:?sequence_node = false

            Push<public>(TriggerWrapper:trigger_device_wrapper, Sequence:cinematic_sequence_device)<transacts>:void =
                NewNode := MakeSequenceNode(Sequence, false, Tail)
                option{TriggerSequenceLookup.Put[TriggerWrapper, NewNode]}
                NewTail := option{NewNode}
                if (Root := Tail?):
                    set Root.Next = NewTail
                set Tail = NewTail
                if (not Head?):
                    set Head = Tail

            Get<public>()<transacts><decides>:cinematic_sequence_device = Current?.Sequence

            Set<public>(Trigger:trigger_device_wrapper)<transacts><decides>:void =
                SequenceNode := TriggerSequenceLookup.Get[Trigger]
                set Current = option{SequenceNode}

            Next<public>()<transacts><decides>:void =
                NextNode := Current?.Next
                set Current = NextNode

            Previous<public>()<transacts><decides>:void =
                PreviousNode := Current?.Prev
                set Current = PreviousNode

            ToBegin<public>():void =
                set Current = Head

        sequence_node<internal> := class<final><unique>:
            Sequence:cinematic_sequence_device
            var Next:?sequence_node
            var Prev:?sequence_node

        trigger_sequence_lookup<internal> := class<final><unique>:
            var BackingMap<private>:[trigger_device_wrapper]sequence_node = map{}

            Get<public>(Trigger:trigger_device_wrapper)<transacts><decides>:sequence_node = BackingMap[Trigger]

            Put<public>(Trigger:trigger_device_wrapper, SequenceNode:sequence_node)<transacts><decides>:void =
                set BackingMap[Trigger] = SequenceNode

        trigger_device_wrapper<internal> := class<final><unique>:
            Trigger:trigger_device

            TriggeredEvent<public>()<transacts>:listenable(?agent) = Trigger.TriggeredEvent

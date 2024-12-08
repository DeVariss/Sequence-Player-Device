sequence_players<public> := module:
    using { /Fortnite.com/Devices }
    using { sequence_containers }
    using { /Verse.org/Simulation }
    
    MakeQueuedSequencePlayer<public><constructor>(SequenceTriggers:sequence_triggers, QueueTriggers:queued_sequence_triggers, SequenceHudMessages:sequence_hud_messages, QueueHudMessages:queued_sequence_hud_messages)<transacts> := queued_sequence_player:
        SequenceTriggers := SequenceTriggers
        QueueTriggers := QueueTriggers
        SequenceHudMessages := SequenceHudMessages
        QueueHudMessages := QueueHudMessages

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

    queued_sequence_player<public> := class<internal><final><unique>(sequence_player, queueable_sequence_player):
        QueueTriggers:queued_sequence_triggers
        QueueHudMessages:queued_sequence_hud_messages

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
                QueueTriggers.Start.TriggeredEvent.Await()
                if (CurrentSequence := MaybeCurrentSequence?):
                    CurrentSequence.StopQueue()
                SequenceQueue.ToBegin()
                if (Sequence := SequenceQueue.Get[]):
                    QueueHudMessages.Start.AttemptShow()
                    Sequence.Play()
                    set MaybeCurrentSequence = option{Sequence}

        AwaitSkipTriggered<override><final>()<suspends>:void =
            loop:
                QueueTriggers.Skip.TriggeredEvent.Await()
                if (CurrentSequence := MaybeCurrentSequence?):
                    QueueHudMessages.Skip.AttemptShow()
                    set IsLooping = false
                    CurrentSequence.Stop()

        AwaitPreviousTriggered<override><final>()<suspends>:void =
            loop:
                QueueTriggers.Previous.TriggeredEvent.Await()
                if (CurrentSequence := MaybeCurrentSequence?):
                    CurrentSequence.StopQueue()
                    if (SequenceQueue.Previous[], PreviousSequence := SequenceQueue.Get[]):
                        QueueHudMessages.Previous.AttemptShow()
                        set MaybeCurrentSequence = option{PreviousSequence}
                        PreviousSequence.Play()

        (Sequence:cinematic_sequence_device).AwaitStopped<override><final>()<suspends>:void =
            loop:
                Sequence.StoppedEvent.Await()
                if (IsLooping?):
                    QueueHudMessages.Looping.AttemptShow()
                    Sequence.Play()
                else if:
                    PlayNextSequence?
                    SequenceQueue.Next[]
                    NextSequence := SequenceQueue.Get[]
                then:
                    QueueHudMessages.Stopped.AttemptShow()
                    set MaybeCurrentSequence = option{NextSequence}
                    NextSequence.Play()

        (TriggerWrapper:trigger_device_wrapper).AwaitTriggered<private>()<suspends>:void =
            TriggeredEvent := TriggerWrapper.TriggeredEvent()
            loop:
                TriggeredEvent.Await()
                if (CurrentSequence := MaybeCurrentSequence?):
                    set IsLooping = false
                    CurrentSequence.StopQueue()
                if (SequenceQueue.Set[TriggerWrapper], Sequence := SequenceQueue.Get[]):
                    set MaybeCurrentSequence = option{Sequence}
                    Sequence.Play()

        (Sequence:cinematic_sequence_device).StopQueue<private>()<suspends>:void =
            set PlayNextSequence = false
            Sequence.Stop()
            Sleep(0.1)
            set PlayNextSequence = true

    sequence_triggers<public> := struct:
        TogglePause:trigger_device
        ToggleLoop:trigger_device

    sequence_hud_messages<public> := struct:
        ToggledPause:?hud_message_device
        UntoggledPause:?hud_message_device
        ToggledLoop:?hud_message_device
        UntoggledLoop:?hud_message_device

    queued_sequence_triggers<public> := struct:
        Start:trigger_device
        Skip:trigger_device
        Previous:trigger_device

    queued_sequence_hud_messages<public> := struct:
        Start:?hud_message_device
        Skip:?hud_message_device
        Previous:?hud_message_device
        Looping:?hud_message_device
        Stopped:?hud_message_device

    (MaybeHudMessage:?hud_message_device).AttemptShow<internal>():void =
        if (HudMessage := MaybeHudMessage?):
            HudMessage.Show()

    sequence_player<internal> := class<abstract>(sequence_player_interface):
        SequenceTriggers:sequence_triggers
        SequenceHudMessages:sequence_hud_messages

        var IsLooping<protected>:logic = false
        var IsPaused<protected>:logic = false
        var MaybeCurrentSequence<protected>:?cinematic_sequence_device = false

        Initialize<override>():void =
            spawn{AwaitTogglePauseTriggered()}
            spawn{AwaitToggleLoopTriggered()}
        
        AwaitTogglePauseTriggered<override><final>()<suspends>:void =
            loop:
                SequenceTriggers.TogglePause.TriggeredEvent.Await()
                if (CurrentSequence := MaybeCurrentSequence?):
                    if (IsPaused?):
                        set IsPaused = false
                        SequenceHudMessages.UntoggledPause.AttemptShow()
                    else:
                        set IsPaused = true
                        SequenceHudMessages.ToggledPause.AttemptShow()
                    CurrentSequence.TogglePause()

        AwaitToggleLoopTriggered<override><final>()<suspends>:void =
            loop:
                SequenceTriggers.ToggleLoop.TriggeredEvent.Await()
                if (IsLooping?):
                    set IsLooping = false
                    SequenceHudMessages.UntoggledLoop.AttemptShow()
                else:
                    set IsLooping = true
                    SequenceHudMessages.ToggledLoop.AttemptShow()
    
    sequence_containers<scoped{sequence_players}> := module:
        MakeTriggerDeviceWrapper<public><constructor>(Trigger:trigger_device)<transacts> := trigger_device_wrapper:
            Trigger := Trigger
    
        sequence_queue<public> := class<final>:
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

        trigger_device_wrapper<public> := class<internal><final><unique>:
            Trigger:trigger_device

            TriggeredEvent<public>()<transacts>:listenable(?agent) = Trigger.TriggeredEvent

        MakeSequenceNode<internal><constructor>(Sequence:cinematic_sequence_device, Next:?sequence_node, Prev:?sequence_node)<transacts> := sequence_node:
            Sequence := Sequence
            Next := Next
            Prev := Prev

        sequence_node<internal> := class<final><unique>:
            Sequence:cinematic_sequence_device
            var Next:?sequence_node
            var Prev:?sequence_node

        trigger_sequence_lookup<internal> := class<final><unique>:
            var BackingMap<private>:[trigger_device_wrapper]sequence_node = map{}

            Get<public>(Trigger:trigger_device_wrapper)<transacts><decides>:sequence_node = BackingMap[Trigger]

            Put<public>(Trigger:trigger_device_wrapper, SequenceNode:sequence_node)<transacts><decides>:void =
                set BackingMap[Trigger] = SequenceNode

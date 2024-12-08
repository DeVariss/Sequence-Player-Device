sequence_manager<public> := module: 
    using { device_options }
    using { /Fortnite.com/Devices }
    using { sequence_players }
    using { /Verse.org/Simulation }

    sequence_manager_device<public> := class<final>(creative_device):
        @editable
        Option_Triggers<private>:sequence_option_triggers = sequence_option_triggers{}

        @editable_container:
            AllowReordering := true
        Sequence_Queue<private>:[]sequence_options = array{}

        OnBegin<override>()<suspends>:void =
            SequencePlayerQueue := Option_Triggers.AsQueuedSequencePlayer()
            SequencePlayerQueue.Initialize()
            for (Option : Sequence_Queue):
                SequencePlayerQueue.Enqueue(Option.Sequence, Option.Trigger)

    device_options<scoped{sequence_manager}> := module:
        (OptionTriggers:sequence_option_triggers).AsQueuedSequencePlayer()<transacts>:queued_sequence_player =
            SequenceTriggers := sequence_triggers:
                TogglePause := OptionTriggers.Pause.Trigger
                ToggleLoop := OptionTriggers.Loop.Trigger
            SequenceHudMessages := sequence_hud_messages:
                ToggledPause := OptionTriggers.Pause.Toggled_Message
                UntoggledPause := OptionTriggers.Pause.Untoggled_Message
                ToggledLoop := OptionTriggers.Loop.Toggled_Message
                UntoggledLoop := OptionTriggers.Loop.Untoggled_Message
            QueueSequenceTriggers := queued_sequence_triggers:
                Start := OptionTriggers.Start.Trigger
                Skip := OptionTriggers.Skip.Trigger
                Previous := OptionTriggers.Previous.Trigger
            QueueSequenceHudMessages := queued_sequence_hud_messages:
                Start := OptionTriggers.Start.Message
                Skip := OptionTriggers.Skip.Message
                Previous := OptionTriggers.Previous.Message
                Looping := OptionTriggers.On_Loop_Message
                Stopped := OptionTriggers.On_Sequence_Ended_Message
            return MakeQueuedSequencePlayer(SequenceTriggers, QueueSequenceTriggers, SequenceHudMessages, QueueSequenceHudMessages)

        sequence_options<public> := struct<concrete>:
            @editable
            Sequence:cinematic_sequence_device = cinematic_sequence_device{}

            @editable
            Trigger:trigger_device = trigger_device{}

        sequence_option_triggers<public> := struct<concrete>:
            @editable
            On_Loop_Message:?hud_message_device = false

            @editable
            On_Sequence_Ended_Message:?hud_message_device = false

            @editable
            Start:trigger_options = trigger_options{}

            @editable
            Pause:toggleable_trigger_options = toggleable_trigger_options{}

            @editable
            Skip:trigger_options = trigger_options{}

            @editable
            Previous:trigger_options = trigger_options{}

            @editable
            Loop:toggleable_trigger_options = toggleable_trigger_options{}

        toggleable_trigger_options<public> := struct<concrete>:
            @editable
            Trigger:trigger_device = trigger_device{}

            @editable
            Toggled_Message:?hud_message_device = false

            @editable
            Untoggled_Message:?hud_message_device = false

        trigger_options<public> := struct<concrete>:
            @editable
            Trigger:trigger_device = trigger_device{}

            @editable
            Message:?hud_message_device = false

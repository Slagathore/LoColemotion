mod recovery_remaining_support_release {
    use super::*;
    use crate::recovery_measured_support_transfer as transfer;
    fn run(remaining:bool,missing:Option<usize>,unknown:bool,ready:bool,dwell:u32,held:u32)->Result<transfer::Receipt> {
        let source=controller();let(mut s,f)=super::recovery_measured_support_transfer::input(&source,2,ready);
        if let Some(i)=missing {s.ordered_contact_observations[i].presence=if unknown {None}else{Some(false)};s.ordered_contact_observations[i].bears_support=Some(false);}
        let mut before=Candidate35ControllerMemory::initial();before.last_semantic_step=Some(1);for l in &mut before.ordered_limb_memory {l.gait_step=90;}
        let mut after=before.clone();for l in &mut after.ordered_limb_memory {l.gait_step+=1;}
        let guard=crate::recovery_support_progression::decide(&crate::recovery_support_progression::Memory::default(),&before,&after,&s,true)?;
        let memory=transfer::Memory{preparation_commands:held,ready_dwell_commands:dwell,..Default::default()};
        let decide=if remaining {transfer::decide_remaining_support}else{transfer::decide};
        decide(&memory,&before,&after,&s,transfer::measure(source.compiled(),&s,&f)?,true,1.0/120.0,0.35,guard)
    }
    #[test] fn planned_unloaded_foot_can_release_but_remaining_support_population_stays_positive() {
        let old=run(false,Some(0),false,true,5,5).unwrap();assert!(!old.preparation_released_this_command);assert_eq!(None,old.required_support_limb_ids);
        let new=run(true,Some(0),false,true,5,5).unwrap();assert!(new.preparation_released_this_command);
        assert_eq!(Some(vec!["front_right".to_owned(),"rear_left".to_owned(),"rear_right".to_owned()]),new.required_support_limb_ids);
        assert_eq!(Some(false),new.planned_swing_contact_required);
        for i in 1..4 {let no=run(true,Some(i),false,true,5,5).unwrap();assert!(!no.readiness_conditions_met && !no.preparation_released_this_command);}
    }
    #[test] fn unknown_planned_contact_margin_dwell_and_timeout_remain_bounded() {
        assert!(run(true,Some(0),true,true,5,5).is_err());
        assert!(!run(true,Some(0),false,false,5,5).unwrap().readiness_conditions_met);
        assert!(!run(true,Some(0),false,true,4,5).unwrap().preparation_released_this_command);
        assert!(run(true,Some(1),false,true,0,240).is_err());
    }
}

class ZZ_ARC_CL_REC_WF definition
  public
  inheriting from CL_SWF_FLEX_IFS_RUN_APPL_BASE
  final
  create public .

public section.

  interfaces IF_SWF_FLEX_IFS_DEF_APPL .

  methods IF_SWF_FLEX_IFS_RUN_APPL_STEP~AFTER_COMPLETION_CALLBACK
    redefinition .
  methods IF_SWF_FLEX_IFS_RUN_APPL_STEP~ON_CREATION_CALLBACK
    redefinition .
  methods IF_SWF_FLEX_IFS_RUN_APPL~RESULT_CALLBACK
    redefinition .
protected section.
private section.
ENDCLASS.



CLASS ZZ_ARC_CL_REC_WF IMPLEMENTATION.


  METHOD if_swf_flex_ifs_run_appl_step~after_completion_callback.
DATA(step_execution_results) = io_current_activity->get_execution_results( ).

    TRY.
        DATA(approval_result) = step_execution_results[ 1 ]-nature.
      CATCH cx_sy_itab_line_not_found.
    ENDTRY.

    IF approval_result EQ 'POSITIVE'.
      ev_action = if_swf_flex_component=>c_action_continue.
    ELSEIF approval_result EQ 'NEGATIVE'. "Means it's rejected
      ev_action = if_swf_flex_component=>c_action_cancel.
    ENDIF.
  ENDMETHOD.


  method IF_SWF_FLEX_IFS_RUN_APPL_STEP~ON_CREATION_CALLBACK.
**TRY.
*CALL METHOD SUPER->IF_SWF_FLEX_IFS_RUN_APPL_STEP~ON_CREATION_CALLBACK
*  EXPORTING
*    IO_CONTEXT          =
*    IO_CURRENT_ACTIVITY =
*    .
**  CATCH cx_swf_flex_ifs_run_exception.
**ENDTRY.
  endmethod.


  METHOD if_swf_flex_ifs_run_appl~result_callback.
    DATA: ls_user_data TYPE zcustusermast.

    DATA(ls_result) = io_result->get_result( ).
    IF ls_result-nature = 'POSITIVE'.
      DATA(lr_wf_container) = io_context->get_workflow_container( ).
      TRY.
          lr_wf_container->get(
            EXPORTING
              name       =  'UserData'               " Name of the Component Whose Value Is to Be Read
            IMPORTING
              value      = ls_user_data ).                 " Copy of the Current Value of the Component
        CATCH cx_swf_cnt_elem_not_found.     " Name Entered Is Unknown
        CATCH cx_swf_cnt_elem_type_conflict. " Value Not Type Compatible to Current Parameter
        CATCH cx_swf_cnt_unit_type_conflict. " Unit Not Type Compatible to the Current Parameter
        CATCH cx_swf_cnt_container.          " Exception in the Container Service
      ENDTRY.

      IF ls_user_data IS NOT INITIAL.
        MODIFY zcustusermast FROM ls_user_data.
      ENDIF.

    ENDIF.
  ENDMETHOD.
ENDCLASS.

class ZCL_ODATA_MSG definition
  public
  final
  create public .

public section.

  class-methods RAISE_BAPIRET2
    importing
      !IO_MC type ref to /IWBEP/IF_MESSAGE_CONTAINER
      !IT_RET type BAPIRET2_T .
protected section.
private section.
ENDCLASS.



CLASS ZCL_ODATA_MSG IMPLEMENTATION.


  METHOD raise_bapiret2.
    LOOP AT it_ret ASSIGNING FIELD-SYMBOL(<r>).
      io_mc->add_message(
        iv_msg_type   = <r>-type
        iv_msg_id     = <r>-id
        iv_msg_number = <r>-number
        iv_msg_text   = <r>-message
        iv_msg_v1     = <r>-message_v1
        iv_msg_v2     = <r>-message_v2
        iv_msg_v3     = <r>-message_v3
        iv_msg_v4     = <r>-message_v4
        iv_add_to_response_header = abap_true ).
    ENDLOOP.
***    RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
***      EXPORTING
***        message_container = io_mc.
  ENDMETHOD.
ENDCLASS.

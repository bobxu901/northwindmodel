*&---------------------------------------------------------------------*
*& Report znwd_data_uploader
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT znwd_data_uploader.

SELECTION-SCREEN: BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  PARAMETERS: p_inv  TYPE c RADIOBUTTON GROUP r1,
              p_cat  TYPE c RADIOBUTTON GROUP r1,
              p_cust TYPE c RADIOBUTTON GROUP r1,
              p_emp  TYPE c RADIOBUTTON GROUP r1,
              p_ordd TYPE c RADIOBUTTON GROUP r1,
              p_ord  TYPE c RADIOBUTTON GROUP r1,
              p_prod TYPE c RADIOBUTTON GROUP r1,
              p_reg  TYPE c RADIOBUTTON GROUP r1,
              p_shp  TYPE c RADIOBUTTON GROUP r1,
              p_sup  TYPE c RADIOBUTTON GROUP r1.
SELECTION-SCREEN: END OF BLOCK b1.

SELECTION-SCREEN: BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
  PARAMETERS: p_file TYPE string.
SELECTION-SCREEN: END OF BLOCK b2.

DATA: it_data TYPE TABLE OF string.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  DATA: lit_ft TYPE filetable,
        ret    TYPE i.
  cl_gui_frontend_services=>file_open_dialog(
    CHANGING
      file_table              = lit_ft
      rc                      = ret
    EXCEPTIONS
      file_open_dialog_failed = 1
      cntl_error              = 2
      error_no_gui            = 3
      not_supported_by_gui    = 4
      OTHERS                  = 5
  ).
  IF sy-subrc <> 0.
    EXIT.
  ELSE.
    READ TABLE lit_ft INTO DATA(ls_ft) INDEX 1.
    p_file = ls_ft-filename.
  ENDIF.

START-OF-SELECTION.
  cl_gui_frontend_services=>gui_upload(
    EXPORTING
      filename                = p_file
    CHANGING
      data_tab                = it_data
    EXCEPTIONS
      file_open_error         = 1
      file_read_error         = 2
      no_batch                = 3
      gui_refuse_filetransfer = 4
      invalid_type            = 5
      no_authority            = 6
      unknown_error           = 7
      bad_data_format         = 8
      header_not_allowed      = 9
      separator_not_allowed   = 10
      header_too_long         = 11
      unknown_dp_error        = 12
      access_denied           = 13
      dp_out_of_memory        = 14
      disk_full               = 15
      dp_timeout              = 16
      not_supported_by_gui    = 17
      error_no_gui            = 18
      OTHERS                  = 19
  ).
  IF sy-subrc <> 0.
    EXIT.
  ENDIF.

  DATA: ls_json TYPE string.
  LOOP AT it_data INTO DATA(ls_upload).
    ls_json = |{ ls_json }| && |{ ls_upload }|.
  ENDLOOP.
  DATA: dynamic_table TYPE REF TO data.
  FIELD-SYMBOLS: <fs> TYPE ANY TABLE.
  /ui2/cl_json=>deserialize(
    EXPORTING
      json             = ls_json
      pretty_name      = /ui2/cl_json=>pretty_mode-none
    CHANGING
      data             = dynamic_table
  ).
  ASSIGN dynamic_table->* TO <fs>.
  FIELD-SYMBOLS <inv> TYPE any.
**********************************************************************
* Upload invoice
**********************************************************************
  IF p_inv IS NOT INITIAL.
    DATA: ls_inv TYPE znwd_invoice,
          lt_inv TYPE TABLE OF znwd_invoice.
    DATA: lt_fields TYPE TABLE OF dd03p.
    CALL FUNCTION 'DDIF_TABL_GET'
      EXPORTING
        name          = 'ZNWD_INVOICE'
      TABLES
        dd03p_tab     = lt_fields
      EXCEPTIONS
        illegal_input = 1
        OTHERS        = 2.

    LOOP AT <fs> ASSIGNING <inv>.
      ASSIGN <inv>->* TO FIELD-SYMBOL(<ls_inv>).
      DATA: ld  TYPE string,
            lld TYPE d.
      LOOP AT lt_fields INTO DATA(ls_field) WHERE fieldname <> 'CLIENT'.
        DATA(ls) = '<ls_inv>-' && |{ ls_field-fieldname }|.
        DATA(lv) = 'ls_inv-' && |{ ls_field-fieldname }|.
        ASSIGN (ls) TO FIELD-SYMBOL(<value>).
        ASSIGN <value>->* TO FIELD-SYMBOL(<final>).
        IF ls_field-fieldname = 'ORDERDATE'
         OR ls_field-fieldname = 'REQUIREDDATE'
         OR ls_field-fieldname = 'SHIPPEDDATE'.
          ld = <final>+6(12).
          cl_pco_utility=>convert_java_timestamp_to_abap(
            EXPORTING
              iv_timestamp = ld
            IMPORTING
              ev_date      = lld
*             ev_time      =
*             ev_msec      =
          ).
          ASSIGN (lv) TO FIELD-SYMBOL(<fm>).
          <fm> = lld.
        ELSE.
          ASSIGN (lv) TO <fm>.
          <fm> = <final>.
        ENDIF.
      ENDLOOP.
      APPEND ls_inv TO lt_inv.
    ENDLOOP.
    DELETE FROM znwd_invoice.
    COMMIT WORK AND WAIT.
    INSERT znwd_invoice FROM TABLE lt_inv.
    COMMIT WORK AND WAIT.
  ENDIF.
**********************************************************************
* Upload Order
**********************************************************************
  IF p_ord IS NOT INITIAL.
    DATA: ls_ord TYPE znwd_order,
          lt_ord TYPE TABLE OF znwd_order.
    CLEAR:lt_fields.
    CALL FUNCTION 'DDIF_TABL_GET'
      EXPORTING
        name          = 'ZNWD_ORDER'
      TABLES
        dd03p_tab     = lt_fields
      EXCEPTIONS
        illegal_input = 1
        OTHERS        = 2.

    LOOP AT <fs> ASSIGNING FIELD-SYMBOL(<ord>).
      ASSIGN <ord>->* TO FIELD-SYMBOL(<ls_ord>).
      LOOP AT lt_fields INTO ls_field WHERE fieldname <> 'CLIENT'.
        ls = '<ls_ord>-' && |{ ls_field-fieldname }|.
        lv = 'ls_ord-' && |{ ls_field-fieldname }|.
        ASSIGN (ls) TO <value>.
        ASSIGN <value>->* TO <final>.
        IF ls_field-fieldname = 'ORDERDATE'
         OR ls_field-fieldname = 'REQUIREDDATE'
         OR ls_field-fieldname = 'SHIPPEDDATE'.
          ld = <final>+6(12).
          cl_pco_utility=>convert_java_timestamp_to_abap(
            EXPORTING
              iv_timestamp = ld
            IMPORTING
              ev_date      = lld
*             ev_time      =
*             ev_msec      =
          ).
          ASSIGN (lv) TO <fm>.
          <fm> = lld.
        ELSE.
          ASSIGN (lv) TO <fm>.
          <fm> = <final>.
        ENDIF.
      ENDLOOP.
      APPEND ls_ord TO lt_ord.
    ENDLOOP.
    DELETE FROM znwd_order.
    COMMIT WORK AND WAIT.
    INSERT znwd_order FROM TABLE lt_ord.
    COMMIT WORK AND WAIT.
  ENDIF.
**********************************************************************
* Upload Product
**********************************************************************
  IF p_prod IS NOT INITIAL.
    DATA: ls_prod TYPE znwd_product,
          lt_prod TYPE TABLE OF znwd_product.
    CLEAR:lt_fields.
    CALL FUNCTION 'DDIF_TABL_GET'
      EXPORTING
        name          = 'ZNWD_PRODUCT'
      TABLES
        dd03p_tab     = lt_fields
      EXCEPTIONS
        illegal_input = 1
        OTHERS        = 2.

    LOOP AT <fs> ASSIGNING FIELD-SYMBOL(<prod>).
      ASSIGN <prod>->* TO FIELD-SYMBOL(<ls_prod>).
      LOOP AT lt_fields INTO ls_field WHERE fieldname <> 'CLIENT'.
        ls = '<ls_prod>-' && |{ ls_field-fieldname }|.
        lv = 'ls_prod-' && |{ ls_field-fieldname }|.
        ASSIGN (ls) TO <value>.
        ASSIGN <value>->* TO <final>.
        ASSIGN (lv) TO <fm>.
        <fm> = <final>.
      ENDLOOP.
      APPEND ls_prod TO lt_prod.
    ENDLOOP.
    DELETE FROM znwd_product.
    COMMIT WORK AND WAIT.
    INSERT znwd_product FROM TABLE lt_prod.
    COMMIT WORK AND WAIT.
  ENDIF.
**********************************************************************
* Upload Region
**********************************************************************
  IF p_reg IS NOT INITIAL.
    DATA: ls_reg TYPE znwd_region,
          lt_reg TYPE TABLE OF znwd_region.
    CLEAR:lt_fields.
    CALL FUNCTION 'DDIF_TABL_GET'
      EXPORTING
        name          = 'ZNWD_REGION'
      TABLES
        dd03p_tab     = lt_fields
      EXCEPTIONS
        illegal_input = 1
        OTHERS        = 2.

    LOOP AT <fs> ASSIGNING FIELD-SYMBOL(<reg>).
      ASSIGN <reg>->* TO FIELD-SYMBOL(<ls_reg>).
      LOOP AT lt_fields INTO ls_field WHERE fieldname <> 'CLIENT'.
        ls = '<ls_reg>-' && |{ ls_field-fieldname }|.
        lv = 'ls_reg-' && |{ ls_field-fieldname }|.
        ASSIGN (ls) TO <value>.
        ASSIGN <value>->* TO <final>.
        ASSIGN (lv) TO <fm>.
        <fm> = <final>.
      ENDLOOP.
      APPEND ls_reg TO lt_reg.
    ENDLOOP.
    DELETE FROM znwd_region.
    COMMIT WORK AND WAIT.
    INSERT znwd_region FROM TABLE lt_reg.
    COMMIT WORK AND WAIT.
  ENDIF.
**********************************************************************
* Upload Category
**********************************************************************
  IF p_cat IS NOT INITIAL.
    DATA: ls_cat TYPE znwd_category,
          lt_cat TYPE TABLE OF znwd_category.
    CLEAR:lt_fields.
    CALL FUNCTION 'DDIF_TABL_GET'
      EXPORTING
        name          = 'ZNWD_CATEGORY'
      TABLES
        dd03p_tab     = lt_fields
      EXCEPTIONS
        illegal_input = 1
        OTHERS        = 2.

    LOOP AT <fs> ASSIGNING FIELD-SYMBOL(<cat>).
      ASSIGN <cat>->* TO FIELD-SYMBOL(<ls_cat>).
      LOOP AT lt_fields INTO ls_field WHERE fieldname <> 'CLIENT'.
        ls = '<ls_cat>-' && |{ ls_field-fieldname }|.
        lv = 'ls_cat-' && |{ ls_field-fieldname }|.
        ASSIGN (ls) TO <value>.
        ASSIGN <value>->* TO <final>.
        ASSIGN (lv) TO <fm>.
        <fm> = <final>.
      ENDLOOP.
      APPEND ls_cat TO lt_cat.
    ENDLOOP.
    DELETE FROM znwd_category.
    COMMIT WORK AND WAIT.
    INSERT znwd_category FROM TABLE lt_cat.
    COMMIT WORK AND WAIT.
  ENDIF.
**********************************************************************
* Upload Customer
**********************************************************************
  IF p_cust IS NOT INITIAL.
    DATA: ls_cus TYPE znwd_customer,
          lt_cus TYPE TABLE OF znwd_customer.
    CLEAR:lt_fields.
    CALL FUNCTION 'DDIF_TABL_GET'
      EXPORTING
        name          = 'ZNWD_CUSTOMER'
      TABLES
        dd03p_tab     = lt_fields
      EXCEPTIONS
        illegal_input = 1
        OTHERS        = 2.

    LOOP AT <fs> ASSIGNING FIELD-SYMBOL(<cus>).
      ASSIGN <cus>->* TO FIELD-SYMBOL(<ls_cus>).
      LOOP AT lt_fields INTO ls_field WHERE fieldname <> 'CLIENT'.
        ls = '<ls_cus>-' && |{ ls_field-fieldname }|.
        lv = 'ls_cus-' && |{ ls_field-fieldname }|.
        ASSIGN (ls) TO <value>.
        ASSIGN <value>->* TO <final>.
        ASSIGN (lv) TO <fm>.
        <fm> = <final>.
      ENDLOOP.
      APPEND ls_cus TO lt_cus.
    ENDLOOP.
    DELETE FROM znwd_customer.
    COMMIT WORK AND WAIT.
    INSERT znwd_customer FROM TABLE lt_cus.
    COMMIT WORK AND WAIT.
  ENDIF.
**********************************************************************
* Upload Employee
**********************************************************************
  IF p_emp IS NOT INITIAL.
    DATA: ls_emp TYPE znwd_employee,
          lt_emp TYPE TABLE OF znwd_employee.
    CLEAR:lt_fields.
    CALL FUNCTION 'DDIF_TABL_GET'
      EXPORTING
        name          = 'ZNWD_EMPLOYEE'
      TABLES
        dd03p_tab     = lt_fields
      EXCEPTIONS
        illegal_input = 1
        OTHERS        = 2.

    LOOP AT <fs> ASSIGNING FIELD-SYMBOL(<emp>).
      ASSIGN <emp>->* TO FIELD-SYMBOL(<ls_emp>).
      LOOP AT lt_fields INTO ls_field WHERE fieldname <> 'CLIENT'.
        ls = '<ls_emp>-' && |{ ls_field-fieldname }|.
        lv = 'ls_emp-' && |{ ls_field-fieldname }|.
        ASSIGN (ls) TO <value>.
        ASSIGN <value>->* TO <final>.
        IF ls_field-fieldname = 'BIRTHDATE'
         OR ls_field-fieldname = 'HIREDATE'.
          ld = <final>+6(12).
          cl_pco_utility=>convert_java_timestamp_to_abap(
            EXPORTING
              iv_timestamp = ld
            IMPORTING
              ev_date      = lld
*             ev_time      =
*             ev_msec      =
          ).
          ASSIGN (lv) TO <fm>.
          <fm> = lld.
        ELSE.
          ASSIGN (lv) TO <fm>.
          IF <final> IS ASSIGNED.
            <fm> = <final>.
            UNASSIGN <final>.
          ENDIF.
          UNASSIGN <fm>.

        ENDIF.
      ENDLOOP.
      APPEND ls_emp TO lt_emp.
    ENDLOOP.
    DELETE FROM znwd_employee.
    COMMIT WORK AND WAIT.
    INSERT znwd_employee FROM TABLE lt_emp.
    COMMIT WORK AND WAIT.
  ENDIF.
**********************************************************************
* Upload Order Detail
**********************************************************************
  IF p_ordd IS NOT INITIAL.
    DATA: ls_odd TYPE znwd_ORDERDETAIL,
          lt_odd TYPE TABLE OF znwd_ORDERDETAIL.
    CLEAR:lt_fields.
    CALL FUNCTION 'DDIF_TABL_GET'
      EXPORTING
        name          = 'ZNWD_ORDERDETAIL'
      TABLES
        dd03p_tab     = lt_fields
      EXCEPTIONS
        illegal_input = 1
        OTHERS        = 2.

    LOOP AT <fs> ASSIGNING FIELD-SYMBOL(<odd>).
      ASSIGN <odd>->* TO FIELD-SYMBOL(<ls_odd>).
      LOOP AT lt_fields INTO ls_field WHERE fieldname <> 'CLIENT'.
        ls = '<ls_odd>-' && |{ ls_field-fieldname }|.
        lv = 'ls_odd-' && |{ ls_field-fieldname }|.
        ASSIGN (ls) TO <value>.
        ASSIGN <value>->* TO <final>.
        ASSIGN (lv) TO <fm>.
        <fm> = <final>.
      ENDLOOP.
      APPEND ls_odd TO lt_odd.
    ENDLOOP.
    DELETE FROM znwd_ORDERDETAIL.
    COMMIT WORK AND WAIT.
    INSERT znwd_ORDERDETAIL FROM TABLE lt_odd.
    COMMIT WORK AND WAIT.
  ENDIF.
**********************************************************************
* Upload Shipper
**********************************************************************
  IF p_shp IS NOT INITIAL.
    DATA: ls_shp TYPE znwd_SHIPPER,
          lt_shp TYPE TABLE OF znwd_SHIPPER.
    CLEAR:lt_fields.
    CALL FUNCTION 'DDIF_TABL_GET'
      EXPORTING
        name          = 'ZNWD_SHIPPER'
      TABLES
        dd03p_tab     = lt_fields
      EXCEPTIONS
        illegal_input = 1
        OTHERS        = 2.

    LOOP AT <fs> ASSIGNING FIELD-SYMBOL(<shp>).
      ASSIGN <shp>->* TO FIELD-SYMBOL(<ls_shp>).
      LOOP AT lt_fields INTO ls_field WHERE fieldname <> 'CLIENT'.
        ls = '<ls_shp>-' && |{ ls_field-fieldname }|.
        lv = 'ls_shp-' && |{ ls_field-fieldname }|.
        ASSIGN (ls) TO <value>.
        ASSIGN <value>->* TO <final>.
        ASSIGN (lv) TO <fm>.
        <fm> = <final>.
      ENDLOOP.
      APPEND ls_shp TO lt_shp.
    ENDLOOP.
    DELETE FROM znwd_SHIPPER.
    COMMIT WORK AND WAIT.
    INSERT znwd_SHIPPER FROM TABLE lt_shp.
    COMMIT WORK AND WAIT.
  ENDIF.
**********************************************************************
* Upload supplier
**********************************************************************
  IF p_sup IS NOT INITIAL.
    DATA: ls_sup TYPE znwd_supplier,
          lt_sup TYPE TABLE OF znwd_supplier.
    CLEAR:lt_fields.
    CALL FUNCTION 'DDIF_TABL_GET'
      EXPORTING
        name          = 'ZNWD_SUPPLIER'
      TABLES
        dd03p_tab     = lt_fields
      EXCEPTIONS
        illegal_input = 1
        OTHERS        = 2.

    LOOP AT <fs> ASSIGNING FIELD-SYMBOL(<sup>).
      ASSIGN <sup>->* TO FIELD-SYMBOL(<ls_sup>).
      LOOP AT lt_fields INTO ls_field WHERE fieldname <> 'CLIENT'.
        ls = '<ls_sup>-' && |{ ls_field-fieldname }|.
        lv = 'ls_sup-' && |{ ls_field-fieldname }|.
        ASSIGN (ls) TO <value>.
        ASSIGN <value>->* TO <final>.
        ASSIGN (lv) TO <fm>.
        <fm> = <final>.
      ENDLOOP.
      APPEND ls_sup TO lt_sup.
    ENDLOOP.
    DELETE FROM znwd_supplier.
    COMMIT WORK AND WAIT.
    INSERT znwd_supplier FROM TABLE lt_sup.
    COMMIT WORK AND WAIT.
  ENDIF.

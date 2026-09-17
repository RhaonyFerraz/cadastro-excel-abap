*&---------------------------------------------------------------------*
*& Include          ZCLIENTES_EXCEL_SEL
*& Descrição:       Tela de Seleção — permite ao usuário informar o
*&                  caminho do arquivo Excel antes da execução.
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* TELA DE SELEÇÃO
*----------------------------------------------------------------------*

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-t01.

  " Parâmetro para o caminho do arquivo Excel
  " PRESENTATION SERVER = arquivo na máquina do usuário (frontend)
  PARAMETERS:
    p_file TYPE string LOWER CASE
           DEFAULT 'C:\temp\clientes.xlsx'
           OBLIGATORY.

SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
* EVENTOS DA TELA DE SELEÇÃO
*----------------------------------------------------------------------*

" AT SELECTION-SCREEN ON VALUE-REQUEST: abre o diálogo de browse de arquivo
AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM f_browse_arquivo.

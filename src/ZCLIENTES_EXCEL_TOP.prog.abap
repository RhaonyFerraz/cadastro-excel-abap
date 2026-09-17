*&---------------------------------------------------------------------*
*& Include          ZCLIENTES_EXCEL_TOP
*& Descrição:       Declarações globais - tipos, tabelas internas e
*&                  variáveis utilizadas em todo o programa.
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* TIPOS LOCAIS
*----------------------------------------------------------------------*

" Estrutura de uma célula retornada pelo RFC ALSM_EXCEL_TO_INTERNAL_TABLE
TYPES: BEGIN OF ty_excel_cell,
         row  TYPE i,       " Linha da planilha
         col  TYPE i,       " Coluna da planilha
         value TYPE char255, " Conteúdo da célula (sempre texto)
       END OF ty_excel_cell.

" Estrutura principal de um cliente lido do Excel
TYPES: BEGIN OF ty_cliente,
         linha    TYPE i,          " Número da linha no Excel (para rastreabilidade)
         status   TYPE icon_d,     " Ícone de semáforo: verde (OK) ou vermelho (ERRO)
         msg_erro TYPE string,     " Descrição do(s) erro(s) encontrado(s)
         nome     TYPE string,     " Nome / Razão Social
         cnpj     TYPE string,     " CNPJ (14 dígitos numéricos)
         endereco TYPE string,     " Logradouro
         cidade   TYPE string,     " Cidade
         uf       TYPE char2,      " Unidade Federativa (estado)
         cep      TYPE string,     " CEP
       END OF ty_cliente.

*----------------------------------------------------------------------*
* TABELAS INTERNAS
*----------------------------------------------------------------------*

" Tabela com as células brutas retornadas pelo Excel
DATA: gt_excel TYPE TABLE OF ty_excel_cell.

" Tabela com os clientes já mapeados e validados
DATA: gt_clientes TYPE TABLE OF ty_cliente.

" Work area para manipulação linha a linha
DATA: gs_cliente TYPE ty_cliente.

*----------------------------------------------------------------------*
* VARIÁVEIS GLOBAIS
*----------------------------------------------------------------------*

" Caminho completo do arquivo selecionado pelo usuário
DATA: gv_filepath TYPE string.

" Referência para o objeto ALV
DATA: go_alv TYPE REF TO cl_salv_table.

" Referências para configuração de colunas do ALV
DATA: go_columns   TYPE REF TO cl_salv_columns_table.
DATA: go_column    TYPE REF TO cl_salv_column_table.
DATA: go_functions TYPE REF TO cl_salv_functions_list.
DATA: go_display   TYPE REF TO cl_salv_display_settings.

" Objeto de exceção genérico para ALV
DATA: gx_salv_error TYPE REF TO cx_salv_error.

*----------------------------------------------------------------------*
* CONSTANTES
*----------------------------------------------------------------------*

CONSTANTS:
  " Ícone de status OK (LED verde) — requer include <icon_d>
  gc_icon_ok    TYPE icon_d VALUE '@08@', " ICON_LED_GREEN
  " Ícone de status ERRO (LED vermelho)
  gc_icon_error TYPE icon_d VALUE '@0A@'. " ICON_LED_RED

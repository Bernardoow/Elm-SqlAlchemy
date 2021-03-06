module Main exposing (..)

import Html exposing (Html, text, div, h1, textarea, p, button, label, code, ul, li, a, span, nav)
import Html.Attributes exposing (class, rows, attribute, href, value, style)
import Html.Events exposing (onInput, onClick)
import Json.Decode as Decoder
import Dict exposing (Dict)
import Regex


---- MODEL ----


type alias Model =
    { querys : Querys
    }


type Querys
    = Empty
    | Querys Int (Dict Int ViewModel)


type alias ViewModel =
    { query : String
    , params : String
    , result : String
    }


type Data
    = IntData Int
    | StringData String
    | FloatData Float


decoderIntData : Decoder.Decoder Data
decoderIntData =
    Decoder.map IntData (Decoder.int)


decoderStringData : Decoder.Decoder Data
decoderStringData =
    Decoder.map StringData (Decoder.string)


decoderFloatData : Decoder.Decoder Data
decoderFloatData =
    Decoder.map FloatData (Decoder.float)


init : ( Model, Cmd Msg )
init =
    ( Model Empty, Cmd.none )



---- UPDATE ----


type Msg
    = OnClickNewQuery
    | InputQuery String
    | InputParams String
    | ChangeQuery Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OnClickNewQuery ->
            let
                querys =
                    case model.querys of
                        Empty ->
                            ViewModel "" "" ""
                                |> Dict.singleton 0
                                |> Querys 0

                        Querys position querys ->
                            let
                                vm =
                                    ViewModel "" "" ""
                            in
                                Dict.insert (Dict.size querys) vm querys
                                    |> Querys (Dict.size querys)
            in
                { model | querys = querys } ! []

        InputQuery str ->
            let
                querys =
                    case model.querys of
                        Empty ->
                            Empty

                        Querys position querys ->
                            case Dict.get position querys of
                                Nothing ->
                                    Querys position querys

                                Just currentQuery ->
                                    let
                                        result =
                                            createQueryReplaced str currentQuery.params

                                        currentQueryUpdated =
                                            { currentQuery | query = str, result = result }
                                    in
                                        Dict.insert position currentQueryUpdated querys
                                            |> Querys position
            in
                { model | querys = querys } ! []

        InputParams str ->
            let
                querys =
                    case model.querys of
                        Empty ->
                            Empty

                        Querys position querys ->
                            case Dict.get position querys of
                                Nothing ->
                                    Querys position querys

                                Just currentQuery ->
                                    let
                                        result =
                                            createQueryReplaced currentQuery.query str

                                        currentQueryUpdated =
                                            { currentQuery | params = str, result = result }
                                    in
                                        Dict.insert position currentQueryUpdated querys
                                            |> Querys position
            in
                { model | querys = querys } ! []

        ChangeQuery new_position ->
            let
                querys =
                    case model.querys of
                        Empty ->
                            Empty

                        Querys position querys ->
                            Querys new_position querys
            in
                { model | querys = querys } ! []


replace_single_quotation_marks_to_double_quotes : String -> String
replace_single_quotation_marks_to_double_quotes text =
    String.map
        (\c ->
            if c == '\'' then
                '"'
            else
                c
        )
        text


replace_none_to_none_with_double_quotes : String -> String
replace_none_to_none_with_double_quotes text =
    let
        regex =
            Regex.regex "None"
    in
        Regex.replace Regex.All regex (\item -> "\"None\"") text


remove_double_quotes_from_none : String -> String
remove_double_quotes_from_none text =
    let
        regex =
            Regex.regex "'None'"
    in
        Regex.replace Regex.All regex (\item -> "None") text


remove_caracter_break_line : String -> String
remove_caracter_break_line text =
    let
        regex_single_escape : Regex.Regex
        regex_single_escape =
            Regex.regex "\\n"

        regex_double_escape : Regex.Regex
        regex_double_escape =
            Regex.regex "\\\\n"
    in
        Regex.replace Regex.All regex_single_escape (\item -> "") text
            |> Regex.replace Regex.All regex_double_escape (\item -> "")


convert_datetime_to_tochar : String -> String
convert_datetime_to_tochar text =
    let
        regex_datetime =
            Regex.regex "datetime.datetime\\((\\d+), (\\d+), (\\d+), (\\d+), (\\d+), (\\d+), \\d+\\)"

        convert_datetime_to_tochar_helper item =
            let
                transform_to_string : Maybe String -> String
                transform_to_string item =
                    case item of
                        Just str ->
                            str

                        Nothing ->
                            ""

                transform_to_tochar list_date =
                    let
                        fix : String -> String
                        fix value =
                            if String.length value == 1 then
                                "0" ++ value
                            else
                                value
                    in
                        case list_date of
                            ano :: mes :: dia :: horas :: minutos :: segundos :: [] ->
                                "TO_DATE('" ++ ano ++ "/" ++ (fix mes) ++ "/" ++ (fix dia) ++ " " ++ (fix horas) ++ ":" ++ (fix minutos) ++ ":" ++ (fix segundos) ++ "', 'YYYY/MM/DD HH24:MI:SS')"

                            _ ->
                                Debug.crash ("Wrong date")
            in
                List.map transform_to_string item.submatches
                    |> List.filter (\i -> String.isEmpty i |> not)
                    |> transform_to_tochar
    in
        Regex.replace Regex.All regex_datetime convert_datetime_to_tochar_helper text


convert_date_to_tochar : String -> String
convert_date_to_tochar text =
    let
        regex_date =
            Regex.regex "datetime.date\\((\\d+), (\\d+), (\\d+)\\)"

        convert_datetime_to_tochar_helper item =
            let
                transform_to_string : Maybe String -> String
                transform_to_string item =
                    case item of
                        Just str ->
                            str

                        Nothing ->
                            ""

                transform_to_tochar list_date =
                    let
                        fix : String -> String
                        fix value =
                            if String.length value == 1 then
                                "0" ++ value
                            else
                                value
                    in
                        case list_date of
                            ano :: mes :: dia :: [] ->
                                "TO_DATE('" ++ ano ++ "/" ++ (fix mes) ++ "/" ++ (fix dia) ++ "', 'YYYY/MM/DD')"

                            _ ->
                                Debug.crash ("Wrong date")
            in
                List.map transform_to_string item.submatches
                    |> List.filter (\i -> String.isEmpty i |> not)
                    |> transform_to_tochar
    in
        Regex.replace Regex.All regex_date convert_datetime_to_tochar_helper text


createQueryReplaced : String -> String -> String
createQueryReplaced query_pre_processed params =
    let
        resultDecoder =
            replace_single_quotation_marks_to_double_quotes params
                |> replace_none_to_none_with_double_quotes
                |> convert_datetime_to_tochar
                |> convert_date_to_tochar
                |> Decoder.decodeString (Decoder.dict (Decoder.oneOf [ decoderIntData, decoderStringData, decoderFloatData ]))

        query =
            remove_caracter_break_line query_pre_processed
    in
        case resultDecoder of
            Ok paramsDict ->
                let
                    replaceData : Data -> String
                    replaceData data =
                        case data of
                            StringData str ->
                                if String.contains "TO_DATE" str then
                                    str
                                else
                                    "'" ++ str ++ "'"

                            FloatData float ->
                                toString float

                            IntData int ->
                                toString int

                    replace : ( String, Data ) -> String -> String
                    replace ( key, value ) query =
                        Regex.replace Regex.All (Regex.regex (":" ++ key)) (\match -> replaceData value) query

                    flippedComparison a b =
                        case compare (Tuple.first a |> String.length) (Tuple.first b |> String.length) of
                            LT ->
                                GT

                            EQ ->
                                EQ

                            GT ->
                                LT
                in
                    Dict.toList paramsDict
                        |> List.sortWith flippedComparison
                        |> List.foldl replace query
                        |> remove_double_quotes_from_none

            Err str_error ->
                str_error



---- VIEW ----


viewPagination : Int -> Int -> Html Msg
viewPagination query_count current_position =
    let
        create_li : Int -> Int -> Html Msg
        create_li current_position number =
            li
                [ if current_position == number then
                    class "active"
                  else
                    class ""
                , ChangeQuery number |> onClick
                ]
                [ a
                    []
                    [ toString (number + 1) |> text ]
                ]

        lis =
            List.range 0 (query_count - 1)
                |> List.map (create_li current_position)

        lis_with_new_query =
            List.append lis [ li [ onClick OnClickNewQuery ] [ a [ style [ ( "margin-left", "10px" ) ] ] [ text "New Query ++" ] ] ]
    in
        div [ class "col-xs-12 col-sm-12 col-md-12 col-lg-12" ]
            [ nav [ attribute "aria-label" "Page navigation" ]
                [ ul [ class "pagination" ]
                    lis_with_new_query
                ]
            ]


view : Model -> Html Msg
view model =
    div [ class "container" ]
        [ h1 [] [ text "Replace params in query" ]
        , case model.querys of
            Empty ->
                div [] [ button [ class "btn btn-default", onClick OnClickNewQuery ] [ text "New Query" ] ]

            Querys position querys ->
                case Dict.get position querys of
                    Nothing ->
                        div [] [ text "Error, position not found." ]

                    Just currentQuery ->
                        div [ class "row" ]
                            [ viewPagination (Dict.size querys) position
                            , div [ class "col-xs-12 col-sm-12 col-md-12 col-lg-12 form-group" ]
                                [ label [] [ "Query " ++ (toString (position + 1)) |> text ]
                                , textarea [ rows 5, class "form-control", onInput InputQuery, value currentQuery.query ] []
                                ]
                            , div [ class "col-xs-12 col-sm-12 col-md-12 col-lg-12 form-group" ]
                                [ label [] [ text "Params" ]
                                , textarea [ value currentQuery.params, rows 5, class "form-control", onInput InputParams ] []
                                ]
                            , if String.isEmpty currentQuery.query || String.isEmpty currentQuery.params then
                                div [] []
                              else
                                div [ class "col-xs-12 col-sm-12 col-md-12 col-lg-12 form-group" ]
                                    [ label [] [ text "Result" ]
                                    , p [] [ code [] [ text currentQuery.result ] ]
                                    ]
                            ]
        ]



---- PROGRAM ----


main : Program Never Model Msg
main =
    Html.program
        { view = view
        , init = init
        , update = update
        , subscriptions = always Sub.none
        }

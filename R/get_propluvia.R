#' Télécharge l'ensemble des données Propluvia à date du jour ou spécifiée
#'
#' @encoding UTF-8
#' @description [get_propluvia()] permet de télécharger les données Propluvia pour la France à une date donnée (par défaut la date du jour).
#' Les données contiennent la géométrie des zones d'alertes.
#' L'argument `export` de la fonction permet de sauvegarder les données au format [`.gpkg`] pour utilisation SIG.
#' Les données mises en forme contiennent une colonne avec le code couleur des zones d'alerte.
#'
#' @param date Date. Par défaut, la date du jour est utilisée. Si elle est renseignée, doit être au format ["\%Y-\%m-\%d"] (ex: 2022-07-23).
#' @param export Valeur logique (par défaut `FALSE`). Si `TRUE`, créer une couche au format [`.gpkg`] dans le répertoire de travail.
#'
#' @return data.frame au format `sf`. Contient les geometry des zones d'alerte.
#' @export
#'
#' @importFrom cli cli cli_h1 cli_abort cli_alert_info cli_alert_danger
#' @importFrom curl has_internet
#' @importFrom dplyr bind_cols mutate case_when
#' @importFrom geojsonsf geojson_sf
#' @importFrom glue glue
#' @importFrom httr GET http_error message_for_status content
#' @importFrom jsonlite fromJSON toJSON
#' @importFrom sf st_as_sf write_sf
#'
#' @examples
#' \dontrun{
#' data_jour <- get_propluvia(export = FALSE)
#' }

get_propluvia <- function(date, export = FALSE){
  
  cli::cli(
    {cli::cli_h1("R\u00e9cup\u00e9ration des donn\u00e9es Propluvia")}
  )
  
  # Check internet connexion
  if (!curl::has_internet()) {
    message("Pas de connexion internet.")
    return(FALSE)
  }
  
  date <- if(missing(date)){format(Sys.time(),'%Y-%m-%d')} else {date}
  
  if(is.na(as.Date(date, format = '%Y-%m-%d'))){
    stop(cli::cli_abort("Mauvais format de date ! (ex: 2022-07-23)"))
  }
  
  # api_url_propluvia
  api_url_propluvia <- glue::glue('https://eau.api.agriculture.gouv.fr/apis/propluvia/zones/{date}')
  
  cli::cli_alert_info("T\u00e9l\u00e9chargement {.url {api_url_propluvia}}")
  
  response <-
    httr::GET(url = api_url_propluvia)
  
  if(httr::http_error(response)) {
    httr::message_for_status(response)
    cli::cli_alert_danger("V\u00e9rifier l\'url dans le navigateur ({.url {api_url_propluvia}})")
  }
  
  cli::cli_alert_info("Assemblage des donn\u00e9es")
  
  response <-
    response %>%
    httr::content('text') %>%
    jsonlite::fromJSON()
  
  data_geometry <-
    response$contourZone$geometry %>%
    jsonlite::toJSON() %>%
    geojsonsf::geojson_sf() %>%
    dplyr::bind_cols(numeroNiveau = as.factor(response$numeroNiveau)) %>%
    dplyr::bind_cols(typeZone = response$typeZone) %>%
    dplyr::bind_cols(nomZone = response$nomZone) %>%
    dplyr::mutate(nomNiveau = dplyr::case_when(numeroNiveau == "1" ~ 'Vigilance',
                                               numeroNiveau == "3" ~ 'Alerte',
                                               numeroNiveau == "4" ~ 'Alerte renforc\u00e9e',
                                               numeroNiveau == "5" ~ 'Crise'),
                  nomNiveau = factor(nomNiveau, levels = c("Vigilance",
                                                           "Alerte",
                                                           "Alerte renforc\u00e9e",
                                                           "Crise"),
                                     ordered = T),
                  colSeuil = dplyr::case_when(numeroNiveau == "1" ~ '#EEEEEE',
                                              numeroNiveau == "3" ~ '#FAE805',
                                              numeroNiveau == "4" ~ '#FF9900',
                                              numeroNiveau == "5" ~ '#FF0000')) %>%
    sf::st_as_sf()
  
  # Export in geopackage
  if(!export == F) {
    cli::cli_alert_info("Export en gpkg {.url {getwd()}}")
    sf::write_sf(obj = data_geometry, dsn = glue::glue("propluvia_{date}.gpkg", append = TRUE))
  }
  
  data_geometry
  
}


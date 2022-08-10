#' Télécharge les données Propluvia pour un département et à date du jour (ou spécifiée)
#'
#' @encoding UTF-8
#' @description [get_propluvia_dpt()] permet de télécharger les données Propluvia pour un département à une date donnée (par défaut la date du jour).
#' Les données contiennent la géométrie des zones d'alertes, et les infos sur les arrêtés en vigueur dans le département.
#' L'argument `export` de la fonction permet de sauvegarder les données au format [`.gpkg`] pour utilisation SIG.
#' Les données mises en forme contiennent également une colonne avec le code couleur des zones d'alerte.
#'
#' @param dpt Numérique. Correspond au numéro de département, par ex. 14 pour le Calvados.
#' @param date Date. Par défaut, la date du jour est utilisée. Si elle est renseignée, doit être au format ["\%Y-\%m-\%d"] (ex: 2022-07-23).
#' @param export Valeur logique (par défaut `FALSE`). Si `TRUE`, créer une couche au format [`.gpkg`] dans le répertoire de travail.
#'
#' @return data.frame au format `sf`. Contient les informations relatives aux arrêtés en vigueur dans le département (numéro, date de signature, date de validité).
#'     Les niveaux de restriction avec leurs dénominations (Vigilance, Alerte, Alerte renforcée, Crise) et le code couleur associé.
#'     Les noms des zones d'alertes.
#'     Les types de zones : superficielles (`SUP`) et/ou souterraines (`SOU`).
#'     Les geometries des zones d'alerte (multipolygones au format WGS84, crs 4326).
#' @export
#'
#' @importFrom cli cli cli_h1 cli_abort cli_alert_info cli_alert_danger
#' @importFrom curl has_internet
#' @importFrom dplyr select mutate left_join bind_cols case_when
#' @importFrom geojsonsf geojson_sf
#' @importFrom glue glue
#' @importFrom httr GET http_error message_for_status content
#' @importFrom jsonlite fromJSON toJSON
#' @importFrom sf st_as_sf write_sf
#'
#' @examples
#' \dontrun{
#' data_jour_dpt14 <- get_propluvia_dpt(dpt = 27,export = FALSE)
#' }

get_propluvia_dpt <- function(dpt, date, export = FALSE){
  
  cli::cli(
    {cli::cli_h1("R\u00e9cup\u00e9ration des donn\u00e9es Propluvia du d\u00e9partement")}
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
  
  if(missing(dpt)) {
    stop(cli::cli_abort("Num\u00e9ro de d\u00e9partement manquant !"))
  }
  
  # api_url_propluvia
  api_url_propluvia <- glue::glue('https://eau.api.agriculture.gouv.fr/apis/propluvia/arretes/{date}/departement/{dpt}')
  
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
  
  part_date_arrete <-
    response %>%
    as.data.frame() %>%
    dplyr::select(-restrictions)
  
  tab_zoneAlerte <-
    response$restrictions[[1]]$zoneAlerte %>%
    dplyr::select(-communes,-contourZone,-departements) %>%
    dplyr::mutate(codeInseeDepartement = as.character(rep({dpt},nrow(.)))) %>%
    dplyr::left_join(part_date_arrete) %>%
    dplyr::bind_cols(niveauRestriction = response$restrictions[[1]]$niveauRestriction) %>%
    dplyr::bind_cols(nomNiveau = response$restrictions[[1]]$nomNiveau) %>%
    dplyr::bind_cols(response$restrictions[[1]]$zoneAlerte$contourZone$geometry %>%
                       jsonlite::toJSON() %>%
                       geojsonsf::geojson_sf()) %>%
    dplyr::mutate(nomNiveau = factor(nomNiveau, levels = c("Vigilance",
                                                           "Alerte",
                                                           "Alerte renforc\u00e9e",
                                                           "Crise"),
                                     ordered = T),
                  colSeuil = dplyr::case_when(niveauRestriction  == "1" ~ '#EEEEEE',
                                              niveauRestriction  == "3" ~ '#FAE805',
                                              niveauRestriction  == "4" ~ '#FF9900',
                                              niveauRestriction  == "5" ~ '#FF0000')) %>%
    sf::st_as_sf()
  
  # Export in geopackage
  if(!export == F) {
    cli::cli_alert_info("Export en gpkg {.url {getwd()}}")
    sf::write_sf(obj = tab_zoneAlerte, dsn = glue::glue("propluvia_dpt{dpt}_{date}.gpkg", append = TRUE))
  }
  
  tab_zoneAlerte
  
}




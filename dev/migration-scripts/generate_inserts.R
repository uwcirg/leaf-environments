# Script to convert R data frame objects to SQL
#
# gently modified from version originally posted to
# https://stackoverflow.com/a/73063553
#
# and extracted from the DBI package

library(DBI)
library(odbc)
library(magrittr)

# suggested usage:
#
#   sink(file = "patient.sql")
#   get_table_sql("patient", as.data.frame(dataset_name))
#   sink(file = NULL)

do_sql_quote_id <- function(x) getMethod("dbQuoteIdentifier", 
                                         c(conn = "DBIConnection",
                                           x="character"))@.Data(x = x)

do_sql_quote_string <- function(x) getMethod("dbQuoteString", 
                                             c(conn = "DBIConnection", 
                                               x = "character"))@.Data(x = x)

do_sql_quote_literal <- function(x) {
  if (is(x, "SQL")) 
    return(x)
  if (is.factor(x)) 
    return(do_sql_quote_string(as.character(x)))
  if (is.character(x)) 
    return(do_sql_quote_string(x))
  if (inherits(x, "POSIXt")) {
    return(do_sql_quote_string(strftime(as.POSIXct(x), "%Y%m%d%H%M%S", 
                                        tz = "UTC")))
  }
  if (inherits(x, "Date")) 
    return(do_sql_quote_string(as.character(x)))
  if (inherits(x, "difftime")) 
    return(do_sql_quote_string(format_hms(x)))
  if (is.list(x)) {
    blob_data <- vapply(x, function(x) {
      if (is.null(x)) {
        "NULL"
      }
      else if (is.raw(x)) {
        paste0("X'", paste(format(x), collapse = ""), 
               "'")
      }
      else {
        stop("Lists must contain raw vectors or NULL", 
             call. = FALSE)
      }
    }, character(1))
    return(SQL(blob_data, names = names(x)))
  }
  if (is.logical(x)) 
    x <- as.numeric(x)
  x <- as.character(x)
  x[is.na(x)] <- "NULL"
  SQL(x, names = names(x))
}

get_data_type <- function(obj) {
  res <- character(NCOL(obj))
  nms <- names(obj)
  for (i in seq_along(obj)) {
    # RK: the SO code seemed to have an outdated method reference
    # res[[i]] <- odbc:::`odbcDataType.Microsoft SQL Server`(obj = obj[[i]])
    #
    # so I used the following statement to dump the supported types:
    #
    # showMethods(odbcDataType)
    #
    # this seems to have worked
    res[[i]] <- odbc:::odbcDataType(con="MySQL", obj = obj[[i]])
  }
  names(res) <- nms
  field_names <- do_sql_quote_id(names(res))
  field_types <- unname(res)
  paste0(field_names, " ", field_types)
}

df_to_sql_data <- function(value) {
  is_POSIXlt <- vapply(value, function(x) is.object(x) && (is(x, 
                                                              "POSIXlt")), logical(1))
  value[is_POSIXlt] <- lapply(value[is_POSIXlt], as.POSIXct)
  is_IDate <- vapply(value, function(x) is.object(x) && (is(x, 
                                                            "IDate")), logical(1))
  value[is_IDate] <- lapply(value[is_IDate], as.Date)
  is_object <- vapply(value, function(x) is.object(x) && !(is(x, 
                                                              "POSIXct") || is(x, "Date") || odbc:::is_blob(x) || 
                                                             is(x, "difftime")), logical(1))
  value[is_object] <- lapply(value[is_object], as.character)
  value
}

get_table_sql <- function(name, my_data) {
  table <- do_sql_quote_id(name)
  fields <- get_data_type(my_data)
  ct <- paste0("CREATE TABLE ", table, " (\n", 
               "  ", paste(fields, collapse = ",\n  "), 
               "\n)\n")
  values <- df_to_sql_data(my_data)
  fields <- do_sql_quote_id(names(values))
  rows <- split(values, seq_len(nrow(values))) %>%
    lapply(function(row) do.call(paste, 
                                 c(sep = ", ", lapply(row, do_sql_quote_literal))))
  it <- paste0("INSERT INTO ", table, " (", 
               paste0(fields, collapse = ", "), ")\n", 
               "VALUES \n", paste0("(", rows, ")", collapse = ", \n"))
  SQL(paste0(ct, "\n", it))
}

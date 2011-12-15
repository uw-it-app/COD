/*jslint nomen: true, regexp: true */
/*global $ */
/*global logger */
/*global RESTDataSource */
/*global badgerArray */
var COD = {},
    toolsAppName = {title: 'COD', href: './'};

(function () {
    'use strict';

    // Datasource locations
    COD.dataSources = {
        "items": "/daw/json/COD/v2/Items",
        "item": "/daw/json/COD/v2/Item"
    };

    // Namespace for JSON data
    COD.data = {};

    // RESTDatasource Error Handler
    COD.RESTErrorHandler = function (XMLHttpRequest, textStatus, errorThrown) {
        logger.debug(errorThrown);
    };

    // REST DataSources
    COD.REST = {};

    // Refresh ID namespace
    COD.rid = {};
    
    COD.hash = undefined;

    COD.getHash = function () {
        var i, segments,
            hash = COD.hash;
        if (COD.hash === undefined) {
            hash = {};
            segments = $(location).attr('hash').replace(/^#/, '').split(/\//);
            if (segments.length >= 2) {
                for (i= 0; i < segments.length; i += 2) {
                    hash[segments[i]] = segments[i+1];
                }
            }
            COD.hash = hash;
        }
        return hash;
    }

}());



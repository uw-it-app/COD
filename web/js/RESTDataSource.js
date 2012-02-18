/*jslint nomen: true, regexp: true */
/*global console*/
/*global $*/
/*glboal JSON*/
/*!
 * Generic REST DataSource code for Create, Read, Update, Delete, Search
 *
 * Need to include jquery and json libraries.
 */
(function () {

    this.RESTDataSource = function (resourceUrl, XHRErrorHandler) {

        this.resourceUrl = resourceUrl;

        this.XHRError = XHRErrorHandler || function (XMLHttpRequest, textStatus, errorThrown) {
            if (console !== undefined) {
                console.error("XHRError: status: " + textStatus + "; error: " + errorThrown);
            }
        };

        // POST
        this.post = function (data, callback, options) {
            this._RESTCall("POST", undefined, {}, data, callback, options);
        };

        // GET
        this.get = function (params, callback, options) {
            this._RESTCall("GET", undefined, params, undefined, callback, options);
        };

        // PUT
        this.put = function (params, data, callback, options) {
            this._RESTCall("PUT", undefined, params, data, callback, options);
        };

        // DELETE
        this.del = function (params, callback, options) {
            this._RESTCall("DELETE", undefined, params, undefined, callback, options);
        };

        this._RESTCall = function (type, dataType, params, data, callback, options) {
            dataType = dataType || "json";

            // standard options
            var parameterString = '',
                pOptions = {
                    type:           type,
                    dataType:       dataType,
                    contentType:    "application/json",
                    error:          this.XHRError,
                    success:        callback
                };

            $.each(params, function (key, value) {
                parameterString += "/" + key + "/" + value;
            });

            $.extend(pOptions, {url: this.resourceUrl + parameterString});

            if (data !== undefined) {
                $.extend(pOptions, {data: JSON.stringify(data)});
            }

            // over-write default options with provided options
            // this includes the URL
            $.extend(pOptions, options);
            // DO IT
            $.ajax(pOptions);
        };

    };
}());

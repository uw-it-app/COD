/*!
 * Generic REST DataSource code for Create, Read, Update, Delete, Search
 *
 * Need to include jquery and json libraries.
 */
 

(function() {
    this.RESTDataSource = function (resourceUrl, XHRErrorHandler) {

        this.resourceUrl=resourceUrl;

        this.XHRError=XHRErrorHandler?XHRErrorHandler:
            function(XMLHttpRequest, textStatus, errorThrown) {
                if(console!==undefined)
                    console.error("XHRError: status: "+textStatus+"; error: "+errorThrown);
            }


            // POST
        this.post   = function(data, callback, options) {
            this._RESTCall("POST", undefined, {}, data, callback, options);
        }

            // GET
        this.get    = function( params, callback, options ) {
            this._RESTCall("GET", undefined, params, undefined, callback, options);
        }

            // PUT
        this.put    = function( params, data, callback, options) {
            this._RESTCall("PUT", undefined, params, data, callback, options);
        };

            // DELETE
        this.delete = function( params, callback, options ) {
            this._RESTCall("DELETE", undefined, params, undefined, callback, options);
        };

        this._RESTCall = function (type, dataType, params, data, callback, options) {
            dataType = dataType ? dataType : "json";

                // standard options
            var pOptions = {
                type:           type,
                dataType:       dataType,
                contentType:    "application/json",
                error:          this.XHRError,
                success:        callback
            };

                // parameterize the URL
            var parameterString='';
            for (var i in params) {
                parameterString+="/"+i+"/"+params[i];
            }
            var url=this.resourceUrl+parameterString;
            jQuery.extend(pOptions, {url: url});

            if( data !== undefined ) {
                var jsonData = JSON.stringify(data);
                jQuery.extend(pOptions, {data: jsonData});
            }

                // over-write default options with provided options
                // this includes the URL
            jQuery.extend(pOptions, options);
                // DO IT
            jQuery.ajax(pOptions);
        }

    }
} ) ();

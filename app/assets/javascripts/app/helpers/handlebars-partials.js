/* we need to wrap this in a document ready to ensure JST is accessible */
$(function(){
  if (typeof JST != "undefined")
    Handlebars.registerPartial('status-message', JST['status-message_tpl']);
});

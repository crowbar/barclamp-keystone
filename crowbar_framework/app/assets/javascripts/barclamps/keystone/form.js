$(document).ready(function($) {
  $('#frontend').on('change', function() {
    if ($(this).val() == 'native') {
      $('#api_protocol').removeAttr('disabled');
    } else {
      $('#api_protocol option')
        .removeAttr('selected')
        .siblings('[value=http]')
        .attr('selected', true)
        .trigger('change');

      $('#api_protocol')
        .attr('disabled', 'disabled');
    }
  }).trigger('change');
});

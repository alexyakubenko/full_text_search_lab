$(document).ready(function() {
  $('button').click(search);

  $('input').keypress(function(e) {
    if(e.which == 13) {
      search();
    }
  })
});

function search() {
  $.get('/search', { q: $('input').val() }, function(response) {
    $('.result').html(response);
  });
}

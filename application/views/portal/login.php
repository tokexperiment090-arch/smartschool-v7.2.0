<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Riyo | Portal Login</title>
  <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css">
  <style>body{background:#7367f0;font-family:Segoe UI,Arial;height:100vh;display:flex;align-items:center;justify-content:center}.card{background:#fff;padding:30px;border-radius:10px;width:360px;box-shadow:0 8px 30px rgba(0,0,0,.2)}.brand{color:#7367f0;font-weight:700}</style>
</head>
<body>
  <div class="card">
    <h4 class="brand text-center">Riyo Portal</h4>
    <p class="text-muted text-center">Mustaqbal Center Clone</p>
    <?php if (isset($error)): ?><div class="alert alert-danger"><?php echo $error; ?></div><?php endif; ?>
    <form method="post" action="<?php echo base_url('portal/login'); ?>">
      <div class="form-group"><input class="form-control" name="username" placeholder="Username" required></div>
      <div class="form-group"><input class="form-control" name="password" type="password" placeholder="Password" required></div>
      <button class="btn btn-primary btn-block" type="submit" style="background:#7367f0;border:none">Login</button>
    </form>
    <p class="text-center mt-2 small text-muted">Default: admin / admin</p>
  </div>
</body>
</html>

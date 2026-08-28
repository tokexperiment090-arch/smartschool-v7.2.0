<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Riyo | Portal</title>
  <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
  <style>
    body{margin:0;font-family:'Lato',sans-serif}
    .sidebar{width:260px;background:#80037F;color:#fff;height:100vh;overflow-y:auto;float:left;padding:15px}
    .sidebar h3{font-size:18px;border-bottom:1px solid #fff3;padding-bottom:10px}
    .sidebar a{display:block;color:#fff;padding:6px 8px;text-decoration:none;border-radius:4px}
    .sidebar a:hover{background:#9c04998c}
    .content{margin-left:260px;padding:25px}
    .mod-title{color:#80037F;font-weight:700}
  </style>
</head>
<body>
  <div class="sidebar">
    <h3>Riyo — Mustaqbal Portal</h3>
    <a href="<?php echo base_url(); ?>portal"><i class="fa fa-home"></i> Dashboard</a>
    <?php if (!empty($user)): ?><a href="<?php echo base_url(); ?>portal/logout"><i class="fa fa-sign-out"></i> Logout (<?php echo htmlspecialchars($user['name']); ?>)</a>
    <?php else: ?><a href="<?php echo base_url(); ?>portal/login"><i class="fa fa-sign-in"></i> Login</a><?php endif; ?>
    <?php foreach($pages as $p): ?>
      <a href="<?php echo base_url(); ?>portal/page/<?php echo $p['id']; ?>"><i class="fa fa-angle-right"></i> <?php echo htmlspecialchars($p['title'] ? $p['title'] : ('Module '.$p['id'])); ?></a>
    <?php endforeach; ?>
  </div>
  <div class="content">
    <h2 class="mod-title">Welcome to Riyo Portal</h2>
    <p>Select a module from the left to view its form. (Cloned from Mustaqbal Center For Special Needs portal.)</p>
  </div>
</body>
</html>

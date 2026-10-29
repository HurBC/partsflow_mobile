abstract class AppRoutes {
  static const login = "/login";
  static const newPassword = "/login/nueva-contrasena";
  static const orders = "/orders";
  static const chat = "/chat";
  static const profile = "/profile";

  // Add more in the future
  static String orderDetail(int id) => "/orders/$id";
  static String chatDetail(String chatId) =>
      "/chat/${Uri.encodeComponent(chatId)}";
}

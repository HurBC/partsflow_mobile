abstract class AppRoutes {
  static const login = "/login";
  static const orders = "/orders";
  static const chat = "/chat";
  static const profile = "/profile";

  // Add more in the future
  static String orderDetail(int id) => "/orders/$id";
  static String chatDetail(int phoneNumber) => "/chat/$phoneNumber";
}

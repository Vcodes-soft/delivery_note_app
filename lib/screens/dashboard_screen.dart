import 'package:delivery_note_app/providers/auth_provider.dart';
import 'package:delivery_note_app/providers/order_provider.dart';
import 'package:delivery_note_app/widgets/dashboard_card.dart';
import 'package:delivery_note_app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((callback) {
      // Provider.of<AuthProvider>(context, listen: false).getCurrentAddress();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      key: scaffoldKey,
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // DrawerHeader(child: SizedBox()),
            Image.asset("assets/bg/drawer_bg.jpeg"),
            Card(
              color: Color.fromRGBO(255, 213, 3, 1.0),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.black),
                        SizedBox(width: 10),
                        Text(
                          'Welcome ${authProvider.username}',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 19,
                            fontStyle: FontStyle.normal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 13),
                  ],
                ),
              ),
            ),
            Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Provider.of<AuthProvider>(context, listen: false)
                    .logout(context);
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromRGBO(255, 213, 3, 1.0),
                  Color.fromRGBO(253, 215, 64, 1.0),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.5, 1.0],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            padding: const EdgeInsets.only(
              top: 50,
              left: 16,
              right: 16,
              bottom: 20,
            ),
            child: Row(
              children: [
                // Techsys logo
                Image.asset(
                  'assets/logo/techsys_logo.png',
                  height: 80,
                  width: 140,
                ),

                // Spacer to push username + icon to the right
                // Spacer(),

                SizedBox(
                  width: 20,
                ),

                // Username + Logout Icon
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 8),
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(255, 191, 61, 1.0),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            authProvider.username ?? "",
                            overflow: TextOverflow.clip,
                            textAlign: TextAlign.center,
                            softWrap: true,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.black),
                        onPressed: () {
                          scaffoldKey.currentState!.openEndDrawer();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                DashboardCard(
                  title: 'Sales Orders',
                  value: "",
                  icon: Icons.shopping_cart,
                  color: Colors.blue,
                  onTap: () => Navigator.of(context).pushNamed('/sales-orders'),
                  image: "assets/bg/sales_order.jpeg",
                ),
                DashboardCard(
                  title: 'Purchase Orders',
                  value: "",
                  icon: Icons.inventory,
                  color: Colors.green,
                  onTap: () =>
                      Navigator.of(context).pushNamed('/purchase-orders'),
                  image: 'assets/bg/purchase_order.jpeg',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
